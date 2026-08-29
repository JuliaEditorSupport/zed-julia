use std::{env, fs, path::Path};

use zed::LanguageServerId;
use zed_extension_api::{
    self as zed,
    lsp::{Completion, CompletionKind, Symbol, SymbolKind},
    process::Command,
    settings::LspSettings,
    CodeLabel, CodeLabelSpan, Result,
};

const JETLS_REPOSITORY: &str = "https://github.com/aviatesk/JETLS.jl";
// Bump this dated tag together with the zed-julia extension release, and keep
// the Julia version bounds below in sync with the `julia` compat declared in
// the pinned revision's Project.toml.
const JETLS_REVISION: &str = "2026-08-29";
// Supported Julia versions, inclusive: the upper bound allows any patch
// release of that minor version (`1.13` allows any Julia 1.13.x).
const JULIA_VERSION_LOWER_BOUND: &str = "1.12.2";
const JULIA_VERSION_UPPER_BOUND: &str = "1.13";
const MANAGED_DEPOTS_DIR: &str = "jetls-depots";

struct JuliaExtension;

impl JuliaExtension {
    fn label_for_completion_impl(&self, completion: Completion) -> Option<CodeLabel> {
        let label = &completion.label;
        let label_len = label.len();

        // For certain kinds, use explicit highlight names instead of Tree-sitter
        let label_span = match completion.kind {
            Some(
                CompletionKind::Struct | CompletionKind::TypeParameter | CompletionKind::Module,
            ) => CodeLabelSpan::literal(label, Some("type".to_string())),
            Some(CompletionKind::Function) => CodeLabelSpan::literal(
                label,
                Some(
                    if label.starts_with('@') {
                        "function.macro"
                    } else {
                        "function.call"
                    }
                    .to_string(),
                ),
            ),
            Some(CompletionKind::Constant) => {
                CodeLabelSpan::literal(label, Some("constant".to_string()))
            }
            Some(CompletionKind::Variable) => {
                CodeLabelSpan::literal(label, Some("variable".to_string()))
            }
            Some(CompletionKind::Keyword) => {
                CodeLabelSpan::literal(label, Some("keyword".to_string()))
            }
            None => CodeLabelSpan::literal(label, None),
            _ => CodeLabelSpan::code_range(zed::Range {
                start: 0,
                end: label_len as u32,
            }),
        };

        let code = label.clone();

        let mut spans = vec![label_span];
        // Add detail (e.g., "::Type") with no highlight (will get fade_out)
        if let Some(detail) = completion
            .label_details
            .as_ref()
            .and_then(|d| d.detail.as_ref())
        {
            spans.push(CodeLabelSpan::literal(detail, None));
        }
        // Add description (e.g., "local", "method") with no highlight (will get fade_out)
        if let Some(desc) = completion
            .label_details
            .as_ref()
            .and_then(|d| d.description.as_ref())
        {
            spans.push(CodeLabelSpan::literal(format!(" {}", desc), None));
        }
        Some(CodeLabel {
            code,
            spans,
            filter_range: zed::Range {
                start: 0,
                end: label_len as u32,
            },
        })
    }

    fn label_for_symbol_impl(&self, symbol: Symbol) -> Option<CodeLabel> {
        let name = &symbol.name;

        // JETLS uses: Module, Function, Struct, Field, Object (argument),
        // Interface (abstract type), Class (primitive type), Constant, Variable,
        // Namespace (let), TypeParameter
        let (prefix, name_highlight) = match symbol.kind {
            SymbolKind::Module => ("module ", "type"),
            SymbolKind::Struct => ("struct ", "type"),
            SymbolKind::Interface => ("abstract type ", "type"),
            SymbolKind::Class => ("primitive type ", "type"),
            SymbolKind::Function => {
                if name.starts_with('@') {
                    ("macro ", "function.macro")
                } else {
                    ("function ", "function")
                }
            }
            SymbolKind::Constant => ("const ", "constant"),
            SymbolKind::Variable | SymbolKind::Object => ("", "variable"),
            SymbolKind::Field => ("", "property"),
            SymbolKind::Namespace => ("let ", "variable"),
            SymbolKind::TypeParameter => ("", "type"),
            _ => ("", ""),
        };

        let code = format!("{}{}", prefix, name);
        let code_len = code.len() as u32;
        let prefix_len = prefix.len() as u32;

        let mut spans = Vec::new();
        if !prefix.is_empty() {
            spans.push(CodeLabelSpan::literal(prefix, Some("keyword".to_string())));
        }
        if name_highlight.is_empty() {
            spans.push(CodeLabelSpan::literal(name, None));
        } else {
            spans.push(CodeLabelSpan::literal(
                name,
                Some(name_highlight.to_string()),
            ));
        }

        Some(CodeLabel {
            code,
            spans,
            filter_range: zed::Range {
                start: prefix_len,
                end: code_len,
            },
        })
    }
}

impl JuliaExtension {
    fn args_for_subcommand(base_args: &[String], subcommand: &str) -> Result<Vec<String>> {
        let serve_positions = base_args
            .iter()
            .enumerate()
            .filter_map(|(index, argument)| (argument == "serve").then_some(index))
            .collect::<Vec<_>>();
        let [serve_position] = serve_positions.as_slice() else {
            return Err(format!(
                "Invalid JETLS binary arguments: expected exactly one `serve` subcommand, got {base_args:?}"
            ));
        };

        let mut args = base_args[..*serve_position].to_vec();
        args.push(subcommand.to_string());
        Ok(args)
    }

    fn settings_env(settings: &LspSettings) -> Vec<(String, String)> {
        settings
            .binary
            .as_ref()
            .and_then(|binary| binary.env.clone())
            .map(|env_map| env_map.into_iter().collect())
            .unwrap_or_default()
    }

    fn command_env(settings: &LspSettings, worktree: &zed::Worktree) -> Vec<(String, String)> {
        let mut env = worktree.shell_env();
        for (key, value) in Self::settings_env(settings) {
            Self::set_env_value(&mut env, &key, value);
        }
        env
    }

    fn env_value<'a>(env: &'a [(String, String)], name: &str) -> Option<&'a str> {
        env.iter()
            .rev()
            .find_map(|(key, value)| (key == name).then_some(value.as_str()))
    }

    fn set_env_value(env: &mut Vec<(String, String)>, name: &str, value: String) {
        env.retain(|(key, _)| key != name);
        env.push((name.to_string(), value));
    }

    fn prepend_path_directory(env: &mut Vec<(String, String)>, directory: &str, platform: zed::Os) {
        let is_windows = matches!(platform, zed::Os::Windows);
        let separator = if is_windows { ';' } else { ':' };
        let is_path_key = |key: &str| {
            if is_windows {
                key.eq_ignore_ascii_case("PATH")
            } else {
                key == "PATH"
            }
        };
        let path = match env
            .iter()
            .rev()
            .find_map(|(key, value)| is_path_key(key).then_some(value.as_str()))
        {
            Some(existing_path) if !existing_path.is_empty() => {
                format!("{directory}{separator}{existing_path}")
            }
            _ => directory.to_string(),
        };
        env.retain(|(key, _)| !is_path_key(key));
        env.push(("PATH".to_string(), path));
    }

    fn resolve_command(
        command: &str,
        description: &str,
        worktree: &zed::Worktree,
    ) -> Result<String> {
        if command.contains('/') || command.contains('\\') {
            Ok(command.to_string())
        } else {
            worktree.which(command).ok_or_else(|| {
                format!(
                    "Unable to find {description} command '{command}'. Make sure it is available in the worktree PATH or specify its full path in Zed settings."
                )
            })
        }
    }

    fn resolve_julia_bin(
        settings_env: &[(String, String)],
        worktree: &zed::Worktree,
    ) -> Result<String> {
        let configured_path =
            Self::env_value(settings_env, "JULIA_APPS_JULIA_CMD").unwrap_or("julia");
        Self::resolve_command(configured_path, "Julia", worktree)
    }

    fn runtime_cache_key(julia_runtime: &str) -> String {
        // Use a fixed hash so cache paths remain stable across extension builds.
        let mut hash = 0xcbf29ce484222325_u64;
        for byte in julia_runtime.bytes() {
            hash ^= u64::from(byte);
            hash = hash.wrapping_mul(0x100000001b3);
        }
        format!("{hash:016x}")
    }

    fn managed_depot_path(julia_runtime: &str) -> Result<String> {
        let current_dir = env::current_dir()
            .map_err(|error| format!("Failed to resolve the extension data directory: {error}"))?;
        Ok(current_dir
            .join(MANAGED_DEPOTS_DIR)
            .join(Self::runtime_cache_key(julia_runtime))
            .to_string_lossy()
            .into_owned())
    }

    fn managed_jetls_bin(depot_path: &str, platform: zed::Os) -> String {
        Path::new(depot_path)
            .join("bin")
            .join(if matches!(platform, zed::Os::Windows) {
                "jetls.bat"
            } else {
                "jetls"
            })
            .to_string_lossy()
            .into_owned()
    }

    fn run_command(
        program: &str,
        args: Vec<String>,
        env: &[(String, String)],
        description: &str,
    ) -> Result<zed::process::Output> {
        Command::new(program)
            .args(args)
            .envs(env.iter().cloned())
            .output()
            .map_err(|error| format!("Failed to run {description} using '{program}': {error}"))
    }

    fn successful_output(output: zed::process::Output, description: &str) -> Result<String> {
        let stdout = String::from_utf8_lossy(&output.stdout);
        let stderr = String::from_utf8_lossy(&output.stderr);
        if output.status != Some(0) {
            return Err(format!(
                "{description} exited with status {:?}\nstdout:\n{stdout}\nstderr:\n{stderr}",
                output.status
            ));
        }
        Ok(stdout.into_owned())
    }

    fn verify_julia_version(julia_bin: &str, env: &[(String, String)]) -> Result<String> {
        let version_check = format!(
            r#"
let lower = v"{JULIA_VERSION_LOWER_BOUND}"
    upper = v"{JULIA_VERSION_UPPER_BOUND}"
    if !(lower <= VERSION && (VERSION.major, VERSION.minor) <= (upper.major, upper.minor))
        println(stderr, "JETLS requires Julia {JULIA_VERSION_LOWER_BOUND} through {JULIA_VERSION_UPPER_BOUND}; found Julia ", VERSION)
        exit(1)
    end
    print(stdout, VERSION)
end
"#
        );
        let output = Self::run_command(
            julia_bin,
            vec![
                "--startup-file=no".to_string(),
                "--history-file=no".to_string(),
                "-e".to_string(),
                version_check,
            ],
            env,
            "the Julia version check",
        )?;
        Self::successful_output(output, "The Julia version check")
    }

    fn run_version_command(
        resolved_bin: &str,
        base_args: &[String],
        env: &[(String, String)],
    ) -> Result<String> {
        let args = Self::args_for_subcommand(base_args, "version")?;
        let output = Self::run_command(resolved_bin, args, env, "the JETLS version check")?;
        Self::successful_output(output, "The JETLS version check")
    }

    fn julia_minor_version(julia_version: &str) -> String {
        julia_version
            .trim()
            .split('.')
            .take(2)
            .collect::<Vec<_>>()
            .join(".")
    }

    // Parses the `jetls version <revision>, julia version <version>` output
    // used by JETLS releases since 2026-08-23.
    fn is_pinned_jetls_version(version_output: &str) -> bool {
        let mut versions = version_output
            .lines()
            .filter_map(|line| line.trim().strip_prefix("jetls version "));
        let (Some(rest), None) = (versions.next(), versions.next()) else {
            return false;
        };
        matches!(
            rest.split(|character: char| character == ',' || character.is_whitespace())
                .next(),
            Some(version) if version == JETLS_REVISION
        )
    }

    fn managed_installation_needs_update(installed_version: Option<&Result<String>>) -> bool {
        !matches!(
            installed_version,
            Some(Ok(version)) if Self::is_pinned_jetls_version(version)
        )
    }

    fn resolve_binary_args(settings: &LspSettings) -> Vec<String> {
        settings
            .binary
            .as_ref()
            .and_then(|b| b.arguments.as_ref())
            .cloned()
            .unwrap_or_else(|| vec!["serve".to_string()])
    }

    fn install_managed_jetls(
        julia_bin: &str,
        depot_path: &str,
        platform: zed::Os,
        env: &[(String, String)],
    ) -> Result<()> {
        fs::create_dir_all(depot_path).map_err(|error| {
            format!("Failed to create the managed JETLS depot '{depot_path}': {error}")
        })?;

        let install_script =
            format!("using Pkg; Pkg.Apps.add(; url={JETLS_REPOSITORY:?}, rev={JETLS_REVISION:?})");
        let mut install_env = env.to_vec();
        Self::set_env_value(&mut install_env, "JULIA_DEPOT_PATH", depot_path.to_string());
        let managed_bin_dir = Path::new(depot_path)
            .join("bin")
            .to_string_lossy()
            .into_owned();
        Self::prepend_path_directory(&mut install_env, &managed_bin_dir, platform);
        let output = Self::run_command(
            julia_bin,
            vec![
                "--startup-file=no".to_string(),
                "--history-file=no".to_string(),
                "-e".to_string(),
                install_script,
            ],
            &install_env,
            "the managed JETLS installation",
        )?;
        Self::successful_output(output, "The managed JETLS installation")?;
        Ok(())
    }

    fn collect_managed_garbage(
        julia_bin: &str,
        depot_path: &str,
        env: &[(String, String)],
    ) -> Result<()> {
        // The depot only needs to serve the pinned release, so reclaim
        // packages orphaned by the update immediately instead of waiting for
        // Pkg's default 7-day grace period.
        const GC_SCRIPT: &str = "import Pkg, Dates; Pkg.gc(; collect_delay=Dates.Day(0))";
        let mut gc_env = env.to_vec();
        Self::set_env_value(&mut gc_env, "JULIA_DEPOT_PATH", depot_path.to_string());
        let output = Self::run_command(
            julia_bin,
            vec![
                "--startup-file=no".to_string(),
                "--history-file=no".to_string(),
                "-e".to_string(),
                GC_SCRIPT.to_string(),
            ],
            &gc_env,
            "the managed JETLS depot garbage collection",
        )?;
        Self::successful_output(output, "The managed JETLS depot garbage collection")?;
        Ok(())
    }

    fn managed_server_command(
        settings: &LspSettings,
        command_env: Vec<(String, String)>,
        worktree: &zed::Worktree,
        server_id: &LanguageServerId,
        platform: zed::Os,
    ) -> Result<zed::Command> {
        let julia_bin = Self::resolve_julia_bin(&command_env, worktree)?;
        let julia_version = Self::verify_julia_version(&julia_bin, &command_env)?;
        // Key the depot by the Julia major.minor version only: the app-env
        // manifest stays valid across patch releases, and `compiled/` already
        // disambiguates patch-level precompilation caches, so patch upgrades
        // reuse the depot instead of orphaning it.
        let julia_runtime = format!("{julia_bin}\n{}", Self::julia_minor_version(&julia_version));

        let depot_path = Self::managed_depot_path(&julia_runtime)?;
        let jetls_bin = Self::managed_jetls_bin(&depot_path, platform);
        let args = Self::resolve_binary_args(settings);
        Self::args_for_subcommand(&args, "version")?;
        let mut launch_env = command_env;
        Self::set_env_value(&mut launch_env, "JULIA_APPS_JULIA_CMD", julia_bin.clone());

        // Failures below implicate the state of the managed depot, so extend
        // them with a manual recovery hint pointing at its location.
        (|| -> Result<()> {
            let installed_version = if fs::metadata(&jetls_bin).is_ok_and(|stat| stat.is_file()) {
                Some(Self::run_version_command(&jetls_bin, &args, &launch_env))
            } else {
                None
            };

            if Self::managed_installation_needs_update(installed_version.as_ref()) {
                zed::set_language_server_installation_status(
                    server_id,
                    &zed::LanguageServerInstallationStatus::Downloading,
                );
                if let Err(installation_error) = Self::install_managed_jetls(
                    &julia_bin,
                    &depot_path,
                    platform,
                    &launch_env,
                ) {
                    let error = if let Some(Err(verification_error)) = installed_version.as_ref() {
                        format!(
                            "The cached managed JETLS installation failed verification:\n{verification_error}\nFailed to repair the managed JETLS installation:\n{installation_error}"
                        )
                    } else {
                        installation_error
                    };
                    return Err(error);
                }

                let installed_version = Self::run_version_command(&jetls_bin, &args, &launch_env)?;
                if !Self::is_pinned_jetls_version(&installed_version) {
                    return Err(format!(
                        "Managed JETLS installation returned an unexpected version. Expected {JETLS_REVISION}, got:\n{installed_version}"
                    ));
                }

                // Garbage collection is housekeeping: the pinned release is already verified above,
                // so do not fail the launch over it.
                if let Err(error) =
                    Self::collect_managed_garbage(&julia_bin, &depot_path, &launch_env)
                {
                    eprintln!("Failed to garbage-collect the managed JETLS depot: {error}");
                }
            }
            Ok(())
        })()
        .map_err(|error| {
            format!(
                "{error}\nIf the error persists, delete the managed JETLS depot at '{depot_path}' and restart the language server."
            )
        })?;

        Ok(zed::Command {
            command: jetls_bin,
            args,
            env: launch_env,
        })
    }
}

impl zed::Extension for JuliaExtension {
    fn new() -> Self {
        Self
    }

    fn language_server_command(
        &mut self,
        server_id: &LanguageServerId,
        worktree: &zed::Worktree,
    ) -> Result<zed::Command> {
        // Zed handles `binary.path` overrides before invoking the extension, so this
        // method only needs to construct commands for the managed installation.
        let settings = LspSettings::for_worktree(server_id.as_ref(), worktree)?;
        let command_env = Self::command_env(&settings, worktree);
        let (platform, _) = zed::current_platform();
        zed::set_language_server_installation_status(
            server_id,
            &zed::LanguageServerInstallationStatus::CheckingForUpdate,
        );

        let result =
            Self::managed_server_command(&settings, command_env, worktree, server_id, platform);

        match result {
            Ok(command) => {
                zed::set_language_server_installation_status(
                    server_id,
                    &zed::LanguageServerInstallationStatus::None,
                );
                Ok(command)
            }
            Err(error) => {
                zed::set_language_server_installation_status(
                    server_id,
                    &zed::LanguageServerInstallationStatus::Failed(error.clone()),
                );
                Err(error)
            }
        }
    }

    fn language_server_initialization_options(
        &mut self,
        server_id: &LanguageServerId,
        worktree: &zed::Worktree,
    ) -> Result<Option<zed::serde_json::Value>> {
        let initialization_options = LspSettings::for_worktree(server_id.as_ref(), worktree)
            .ok()
            .and_then(|s| s.initialization_options.clone());
        Ok(initialization_options)
    }

    fn language_server_workspace_configuration(
        &mut self,
        server_id: &LanguageServerId,
        worktree: &zed::Worktree,
    ) -> Result<Option<zed::serde_json::Value>> {
        let settings = LspSettings::for_worktree(server_id.as_ref(), worktree)
            .ok()
            .and_then(|s| s.settings.clone())
            .unwrap_or_else(|| zed::serde_json::json!({}));
        // Wrap settings under "jetls" namespace for workspace/configuration
        Ok(Some(zed::serde_json::json!({ "jetls": settings })))
    }

    fn label_for_completion(
        &self,
        _server_id: &LanguageServerId,
        completion: Completion,
    ) -> Option<CodeLabel> {
        self.label_for_completion_impl(completion)
    }

    fn label_for_symbol(&self, _server_id: &LanguageServerId, symbol: Symbol) -> Option<CodeLabel> {
        self.label_for_symbol_impl(symbol)
    }
}

zed::register_extension!(JuliaExtension);

#[cfg(test)]
mod tests {
    use super::*;

    fn strings(values: &[&str]) -> Vec<String> {
        values.iter().map(|value| value.to_string()).collect()
    }

    #[test]
    fn derives_sibling_jetls_subcommands() {
        let args = strings(&["--threads=1", "--", "serve", "ignored"]);
        assert_eq!(
            JuliaExtension::args_for_subcommand(&args, "version").unwrap(),
            strings(&["--threads=1", "--", "version"])
        );
    }

    #[test]
    fn rejects_ambiguous_serve_subcommands() {
        let missing = strings(&["--threads=1"]);
        assert!(JuliaExtension::args_for_subcommand(&missing, "version").is_err());

        let repeated = strings(&["serve", "--", "serve"]);
        assert!(JuliaExtension::args_for_subcommand(&repeated, "version").is_err());
    }

    #[test]
    fn recognizes_only_the_pinned_jetls_version() {
        assert!(JuliaExtension::is_pinned_jetls_version(&format!(
            "jetls version {JETLS_REVISION}, julia version 1.12.6\n"
        )));
        assert!(JuliaExtension::is_pinned_jetls_version(&format!(
            "jetls version {JETLS_REVISION}\n"
        )));
        assert!(!JuliaExtension::is_pinned_jetls_version(
            "jetls version 2026-08-01, julia version 1.12.6\n"
        ));
        // The pre-2026-08-23 output format signals a stale installation.
        assert!(!JuliaExtension::is_pinned_jetls_version(&format!(
            "JETLS version {JETLS_REVISION} on Julia 1.12.6\n"
        )));
        assert!(!JuliaExtension::is_pinned_jetls_version(&format!(
            "jetls version {JETLS_REVISION}\njetls version {JETLS_REVISION}\n"
        )));
        assert!(!JuliaExtension::is_pinned_jetls_version(
            "unexpected output\n"
        ));
    }

    #[test]
    fn requests_update_unless_the_pinned_version_is_verified() {
        // Not installed yet.
        assert!(JuliaExtension::managed_installation_needs_update(None));
        // Installed, but failed verification (e.g., a corrupted depot).
        assert!(JuliaExtension::managed_installation_needs_update(Some(
            &Err("The JETLS version check exited with status Some(1)".to_string())
        )));
        // Installed, but at a different pin.
        assert!(JuliaExtension::managed_installation_needs_update(Some(
            &Ok("jetls version 2026-08-01, julia version 1.12.6\n".to_string())
        )));
        // Installed at the pinned version.
        assert!(!JuliaExtension::managed_installation_needs_update(Some(
            &Ok(format!(
                "jetls version {JETLS_REVISION}, julia version 1.12.6\n"
            ))
        )));
    }

    #[test]
    fn replaces_environment_values_instead_of_duplicating_them() {
        let mut env = vec![
            ("OTHER".to_string(), "value".to_string()),
            ("JULIA_DEPOT_PATH".to_string(), "old".to_string()),
        ];
        JuliaExtension::set_env_value(&mut env, "JULIA_DEPOT_PATH", "managed".to_string());

        assert_eq!(
            JuliaExtension::env_value(&env, "JULIA_DEPOT_PATH"),
            Some("managed")
        );
        assert_eq!(
            env.iter()
                .filter(|(key, _)| key == "JULIA_DEPOT_PATH")
                .count(),
            1
        );
    }

    #[test]
    fn prepends_the_managed_app_bin_to_path() {
        let mut mac_env = vec![("PATH".to_string(), "/usr/bin".to_string())];
        JuliaExtension::prepend_path_directory(&mut mac_env, "/managed/bin", zed::Os::Mac);
        assert_eq!(
            mac_env,
            vec![("PATH".to_string(), "/managed/bin:/usr/bin".to_string())]
        );

        let mut windows_env = vec![("Path".to_string(), r"C:\Windows\System32".to_string())];
        JuliaExtension::prepend_path_directory(
            &mut windows_env,
            r"C:\managed\bin",
            zed::Os::Windows,
        );
        assert_eq!(
            windows_env,
            vec![(
                "PATH".to_string(),
                r"C:\managed\bin;C:\Windows\System32".to_string()
            )]
        );
    }

    #[test]
    fn keys_the_depot_by_julia_minor_version() {
        assert_eq!(JuliaExtension::julia_minor_version("1.12.6"), "1.12");
        assert_eq!(JuliaExtension::julia_minor_version("1.12.7\n"), "1.12");
        assert_eq!(JuliaExtension::julia_minor_version("1.13.0-rc1"), "1.13");
    }

    #[test]
    fn uses_separate_caches_for_different_julia_runtimes() {
        let julia_112 = "/path/to/julia\n1.12";
        let julia_113 = "/path/to/julia\n1.13";
        let other_julia_112 = "/other/path/to/julia\n1.12";

        assert_eq!(
            JuliaExtension::runtime_cache_key(julia_112),
            "fe6aa0725209c575"
        );
        assert_ne!(
            JuliaExtension::runtime_cache_key(julia_112),
            JuliaExtension::runtime_cache_key(julia_113)
        );
        assert_ne!(
            JuliaExtension::runtime_cache_key(julia_112),
            JuliaExtension::runtime_cache_key(other_julia_112)
        );
    }
}

use std::{
    env, fs, io,
    path::{Path, PathBuf},
    time::{Duration, SystemTime, UNIX_EPOCH},
};

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
// the pinned revision's Project.toml; CI verifies the bounds via `scripts/check-julia-bounds.sh`.
const JETLS_REVISION: &str = "2026-08-29";
// Supported Julia versions, inclusive: the upper bound allows any patch
// release of that minor version (`1.13` allows any Julia 1.13.x).
const JULIA_VERSION_LOWER_BOUND: &str = "1.12.2";
const JULIA_VERSION_UPPER_BOUND: &str = "1.13";
const MANAGED_DEPOTS_DIR: &str = "jetls-depots";
const CURRENT_POINTER_FILE: &str = "current";
const INSTALL_STAMP_FILE: &str = "install-stamp.json";
const LAST_USED_FILE: &str = "last-used";
// An unpublished generation may hold an installation still in progress
// (including one whose process outlived its Zed window), so it is only
// removed well past any plausible installation lifetime.
const UNPUBLISHED_GENERATION_GRACE: Duration = Duration::from_secs(24 * 60 * 60);
// A published but unreferenced generation may still be running a server in
// another window; it is removed only after no start has resolved it for long
// enough that no live window plausibly uses it.
const GENERATION_RETENTION: Duration = Duration::from_secs(7 * 24 * 60 * 60);
// A whole runtime container goes stale when the user switches Julia (another
// executable, or another minor version). The retention is long because
// reclaiming a runtime the user switches back to costs a full reinstall.
const RUNTIME_RETENTION: Duration = Duration::from_secs(30 * 24 * 60 * 60);

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

    fn command_env(
        settings: &LspSettings,
        worktree: &zed::Worktree,
        platform: zed::Os,
    ) -> Vec<(String, String)> {
        let mut env = worktree.shell_env();
        for (key, value) in Self::settings_env(settings) {
            Self::set_env_value(&mut env, &key, value, platform);
        }
        env
    }

    // Windows environment variable names are case-insensitive, so lookups and
    // replacements must not miss (or duplicate) keys differing only in case.
    fn env_key_matches(key: &str, name: &str, platform: zed::Os) -> bool {
        if matches!(platform, zed::Os::Windows) {
            key.eq_ignore_ascii_case(name)
        } else {
            key == name
        }
    }

    fn env_value<'a>(
        env: &'a [(String, String)],
        name: &str,
        platform: zed::Os,
    ) -> Option<&'a str> {
        env.iter().rev().find_map(|(key, value)| {
            Self::env_key_matches(key, name, platform).then_some(value.as_str())
        })
    }

    fn set_env_value(
        env: &mut Vec<(String, String)>,
        name: &str,
        value: String,
        platform: zed::Os,
    ) {
        env.retain(|(key, _)| !Self::env_key_matches(key, name, platform));
        env.push((name.to_string(), value));
    }

    fn prepend_path_directory(env: &mut Vec<(String, String)>, directory: &str, platform: zed::Os) {
        let path = match Self::env_value(env, "PATH", platform) {
            Some(existing_path) if !existing_path.is_empty() => {
                let separator = Self::path_list_separator(platform);
                format!("{directory}{separator}{existing_path}")
            }
            _ => directory.to_string(),
        };
        Self::set_env_value(env, "PATH", path, platform);
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
        platform: zed::Os,
    ) -> Result<String> {
        let configured_path =
            Self::env_value(settings_env, "JULIA_APPS_JULIA_CMD", platform).unwrap_or("julia");
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

    fn managed_container_path(julia_runtime: &str) -> Result<String> {
        let current_dir = env::current_dir()
            .map_err(|error| format!("Failed to resolve the extension data directory: {error}"))?;
        Ok(current_dir
            .join(MANAGED_DEPOTS_DIR)
            .join(Self::runtime_cache_key(julia_runtime))
            .to_string_lossy()
            .into_owned())
    }

    fn current_pointer_path(container_path: &str) -> PathBuf {
        Path::new(container_path).join(CURRENT_POINTER_FILE)
    }

    fn install_stamp_path(generation_path: &Path) -> PathBuf {
        generation_path.join(INSTALL_STAMP_FILE)
    }

    fn last_used_path(base_path: &Path) -> PathBuf {
        base_path.join(LAST_USED_FILE)
    }

    fn unix_nanos() -> u128 {
        SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map(|elapsed| elapsed.as_nanos())
            .unwrap_or(0)
    }

    // A generation directory is never renamed once the installation ran:
    // precompile caches record absolute source paths, so publication happens
    // by pointing `current` at the directory, not by moving it.
    fn new_generation_id() -> String {
        format!("{JETLS_REVISION}-{:x}", Self::unix_nanos())
    }

    fn create_generation_directory(container_path: &str) -> Result<(String, String)> {
        for _ in 0..8 {
            let generation_id = Self::new_generation_id();
            let generation_path = Path::new(container_path).join(&generation_id);
            match fs::create_dir(&generation_path) {
                Ok(()) => {
                    return Ok((
                        generation_id,
                        generation_path.to_string_lossy().into_owned(),
                    ))
                }
                Err(error) if error.kind() == io::ErrorKind::AlreadyExists => continue,
                Err(error) => {
                    return Err(format!(
                        "Failed to create a managed JETLS generation in '{container_path}': {error}"
                    ))
                }
            }
        }
        Err(format!(
            "Failed to allocate a fresh managed JETLS generation in '{container_path}'"
        ))
    }

    fn read_current_generation(container_path: &str) -> Option<String> {
        let pointer = fs::read_to_string(Self::current_pointer_path(container_path)).ok()?;
        let pointer: zed::serde_json::Value = zed::serde_json::from_str(&pointer).ok()?;
        let generation_id = pointer.get("generation")?.as_str()?;
        if generation_id.is_empty()
            || generation_id.starts_with('.')
            || generation_id.contains('/')
            || generation_id.contains('\\')
            // A ':' can carry a Windows drive prefix (e.g. `C:evil`), which
            // `Path::join` treats as a fresh path escaping the container.
            || generation_id.contains(':')
        {
            return None;
        }
        let generation_path = Path::new(container_path).join(generation_id);
        fs::metadata(&generation_path)
            .is_ok_and(|stat| stat.is_dir())
            .then(|| generation_path.to_string_lossy().into_owned())
    }

    // Publishes a file through a uniquely named temp file and a rename, so a
    // concurrent reader never sees torn content and the last of concurrent
    // publishers wins. Some hosts refuse to rename over an existing file; the
    // fallback loses atomicity, but a reader hitting the gap only re-installs.
    fn replace_file(file_path: &Path, content: &str) -> io::Result<()> {
        let mut temp_path = file_path.as_os_str().to_owned();
        temp_path.push(format!(".{:x}.tmp", Self::unix_nanos()));
        let temp_path = PathBuf::from(temp_path);
        fs::write(&temp_path, content)?;
        fs::rename(&temp_path, file_path).or_else(|_| {
            let _ = fs::remove_file(file_path);
            fs::rename(&temp_path, file_path)
        })
    }

    // Every published generation is complete, so either of two concurrent
    // publishers is a valid winner.
    fn write_current_generation(container_path: &str, generation_id: &str) -> Result<()> {
        let pointer = zed::serde_json::json!({ "generation": generation_id }).to_string();
        Self::replace_file(&Self::current_pointer_path(container_path), &pointer)
            .map_err(|error| format!("Failed to publish the managed JETLS generation: {error}"))
    }

    // The stamp marks the generation complete for cleanup (a missing stamp
    // means a possibly in-progress installation). Best-effort: without it the
    // generation is merely reclaimed on the shorter grace once superseded.
    //
    // The recorded (pin, exact Julia version) pair would also allow skipping
    // the per-start `jetls version` probe (~1s warm) like jetls-vscode does.
    // Adopting that fast path needs a way to invalidate the stamp of a broken
    // generation, but Zed neither notifies extensions of server failures nor
    // auto-restarts crashed servers, so a stale stamp would pin starts to a
    // failure loop that only manual storage deletion escapes. Revisit if Zed
    // gains a failure signal.
    fn write_install_stamp(generation_path: &str, julia_version: &str) {
        let stamp = zed::serde_json::json!({
            "revision": JETLS_REVISION,
            "julia": julia_version,
        })
        .to_string();
        let _ = Self::replace_file(
            &Self::install_stamp_path(Path::new(generation_path)),
            &stamp,
        );
    }

    // Records that a start resolved this generation (or runtime container),
    // so cleanup keeps what a still-open window may be running a server from.
    fn touch_last_used(base_path: &Path) {
        let _ = fs::write(Self::last_used_path(base_path), "");
    }

    fn path_age(path: &Path) -> Option<Duration> {
        let modified = fs::metadata(path).ok()?.modified().ok()?;
        SystemTime::now().duration_since(modified).ok()
    }

    fn entry_age(path: &Path) -> Option<Duration> {
        Self::path_age(&Self::last_used_path(path)).or_else(|| Self::path_age(path))
    }

    fn should_remove_entry(published: bool, age: Option<Duration>) -> bool {
        let grace = if published {
            GENERATION_RETENTION
        } else {
            UNPUBLISHED_GENERATION_GRACE
        };
        age.is_some_and(|age| age > grace)
    }

    fn remove_path(path: &Path) {
        let _ = if fs::metadata(path).is_ok_and(|stat| stat.is_dir()) {
            fs::remove_dir_all(path)
        } else {
            fs::remove_file(path)
        };
    }

    // Removes what no start can need anymore: unpublished generations old
    // enough that no installation can still be producing them, published
    // generations that no start has resolved within the retention, and
    // sibling runtime containers the user stopped using. Container entries
    // that are not control files are judged as generations, which also ages
    // out depots from the pre-generation layout. The current generation and
    // the active container are never touched. Best-effort: a failure only
    // defers cleanup.
    fn cleanup_managed_storage(container_path: &str) {
        let current_generation = Self::read_current_generation(container_path);
        if let Ok(entries) = fs::read_dir(container_path) {
            for entry in entries.flatten() {
                let name = entry.file_name().to_string_lossy().into_owned();
                if name == CURRENT_POINTER_FILE || name == LAST_USED_FILE {
                    continue;
                }
                let entry_path = entry.path();
                if current_generation.as_deref() == Some(entry_path.to_string_lossy().as_ref()) {
                    continue;
                }
                let published = fs::metadata(Self::install_stamp_path(&entry_path))
                    .is_ok_and(|stat| stat.is_file());
                if Self::should_remove_entry(published, Self::entry_age(&entry_path)) {
                    Self::remove_path(&entry_path);
                }
            }
        }
        let Some(depots_path) = Path::new(container_path).parent() else {
            return;
        };
        // The sweep deletes whole directory trees, so refuse to run anywhere
        // but the extension's own storage directory.
        if depots_path
            .file_name()
            .is_none_or(|name| name != MANAGED_DEPOTS_DIR)
        {
            return;
        }
        if let Ok(entries) = fs::read_dir(depots_path) {
            for entry in entries.flatten() {
                let entry_path = entry.path();
                if entry_path == Path::new(container_path) {
                    continue;
                }
                if Self::entry_age(&entry_path).is_some_and(|age| age > RUNTIME_RETENTION) {
                    Self::remove_path(&entry_path);
                }
            }
        }
    }

    fn path_list_separator(platform: zed::Os) -> char {
        if matches!(platform, zed::Os::Windows) {
            ';'
        } else {
            ':'
        }
    }

    // `JULIA_DEPOT_PATH` for the maintenance commands (install, gc): writes go
    // to the managed depot, the trailing empty entry appends the bundled system
    // depots so stdlib caches are reused, and the user depot stays out of the
    // chain so the managed depot remains self-contained.
    fn maintenance_depot_chain(depot_path: &str, platform: zed::Os) -> String {
        format!("{depot_path}{}", Self::path_list_separator(platform))
    }

    fn managed_environment(depot_path: &str) -> String {
        Path::new(depot_path)
            .join("environments")
            .join("apps")
            .join("JETLS")
            .to_string_lossy()
            .into_owned()
    }

    fn server_depot_chain(env: &[(String, String)], depot_path: &str, platform: zed::Os) -> String {
        let separator = Self::path_list_separator(platform);
        if let Some(user_chain) =
            Self::env_value(env, "JULIA_DEPOT_PATH", platform).filter(|chain| !chain.is_empty())
        {
            return format!("{depot_path}{separator}{user_chain}");
        }
        let home_key = if matches!(platform, zed::Os::Windows) {
            "USERPROFILE"
        } else {
            "HOME"
        };
        match Self::env_value(env, home_key, platform).filter(|home| !home.is_empty()) {
            // The trailing empty entry appends the bundled system depots.
            Some(home) => format!("{depot_path}{separator}{home}/.julia{separator}"),
            None => format!("{depot_path}{separator}"),
        }
    }

    // The server launches as `julia -m JETLS` against the managed app
    // environment with an explicit depot chain: every write stays in the
    // managed depot (it comes first), while packages and precompile caches
    // already present in the user's own chain stay readable and reused for
    // analyzing workspace dependencies.
    fn server_launch_env(
        mut env: Vec<(String, String)>,
        depot_path: &str,
        platform: zed::Os,
    ) -> Vec<(String, String)> {
        let depot_chain = Self::server_depot_chain(&env, depot_path, platform);
        Self::set_env_value(&mut env, "JULIA_DEPOT_PATH", depot_chain, platform);
        let load_path = Self::managed_environment(depot_path);
        Self::set_env_value(&mut env, "JULIA_LOAD_PATH", load_path, platform);
        env
    }

    // Mirror the shim's argument protocol: arguments before a `--` separator go
    // to `julia` itself, the rest to the JETLS app.
    fn julia_launch_args(shim_args: &[String]) -> Vec<String> {
        let (julia_args, app_args) = match shim_args.iter().position(|arg| arg == "--") {
            Some(separator) => (&shim_args[..separator], &shim_args[separator + 1..]),
            None => (&shim_args[..0], shim_args),
        };
        let mut args = vec![
            "--startup-file=no".to_string(),
            "--history-file=no".to_string(),
            "--threads=auto".to_string(),
        ];
        args.extend(julia_args.iter().cloned());
        args.push("-m".to_string());
        args.push("JETLS".to_string());
        args.extend(app_args.iter().cloned());
        args
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
        julia_bin: &str,
        base_args: &[String],
        env: &[(String, String)],
    ) -> Result<String> {
        let subcommand_args = Self::args_for_subcommand(base_args, "version")?;
        let args = Self::julia_launch_args(&subcommand_args);
        let output = Self::run_command(julia_bin, args, env, "the JETLS version check")?;
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
        let depot_chain = Self::maintenance_depot_chain(depot_path, platform);
        Self::set_env_value(&mut install_env, "JULIA_DEPOT_PATH", depot_chain, platform);
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

    fn install_generation(
        julia_bin: &str,
        container_path: &str,
        julia_version: &str,
        args: &[String],
        command_env: &[(String, String)],
        platform: zed::Os,
    ) -> Result<String> {
        let (generation_id, generation_path) = Self::create_generation_directory(container_path)?;
        Self::install_managed_jetls(julia_bin, &generation_path, platform, command_env)?;
        let launch_env = Self::server_launch_env(command_env.to_vec(), &generation_path, platform);
        let installed_version = Self::run_version_command(julia_bin, args, &launch_env)?;
        if !Self::is_pinned_jetls_version(&installed_version) {
            return Err(format!(
                "Managed JETLS installation returned an unexpected version. Expected {JETLS_REVISION}, got:\n{installed_version}"
            ));
        }
        Self::write_install_stamp(&generation_path, julia_version);
        Self::write_current_generation(container_path, &generation_id)?;
        Ok(generation_path)
    }

    fn managed_server_command(
        settings: &LspSettings,
        command_env: Vec<(String, String)>,
        worktree: &zed::Worktree,
        server_id: &LanguageServerId,
        platform: zed::Os,
    ) -> Result<zed::Command> {
        let julia_bin = Self::resolve_julia_bin(&command_env, worktree, platform)?;
        let julia_version = Self::verify_julia_version(&julia_bin, &command_env)?;
        // Key the depot by the Julia major.minor version only: the app-env
        // manifest stays valid across patch releases, and `compiled/` already
        // disambiguates patch-level precompilation caches, so patch upgrades
        // reuse the depot instead of orphaning it.
        let julia_runtime = format!("{julia_bin}\n{}", Self::julia_minor_version(&julia_version));

        let container_path = Self::managed_container_path(&julia_runtime)?;
        let args = Self::resolve_binary_args(settings);
        Self::args_for_subcommand(&args, "version")?;

        fs::create_dir_all(&container_path).map_err(|error| {
            format!("Failed to create the managed JETLS storage '{container_path}': {error}")
        })?;
        // Keep the runtime container alive against the stale-runtime sweep
        // while a potentially long installation runs.
        Self::touch_last_used(Path::new(&container_path));

        // Updates never touch the published generation: a failed or aborted
        // installation only strands its own unpublished generation (later
        // reclaimed by cleanup), so a retry starts from a clean slate.
        let generation_path = (|| -> Result<String> {
            let current_generation = Self::read_current_generation(&container_path);
            let installed_version = current_generation.as_ref().map(|generation| {
                let probe_env = Self::server_launch_env(command_env.clone(), generation, platform);
                Self::run_version_command(&julia_bin, &args, &probe_env)
            });
            if let (Some(generation), false) = (
                &current_generation,
                Self::managed_installation_needs_update(installed_version.as_ref()),
            ) {
                return Ok(generation.clone());
            }

            zed::set_language_server_installation_status(
                server_id,
                &zed::LanguageServerInstallationStatus::Downloading,
            );
            Self::install_generation(
                &julia_bin,
                &container_path,
                &julia_version,
                &args,
                &command_env,
                platform,
            )
            .map_err(|installation_error| {
                if let Some(Err(verification_error)) = installed_version.as_ref() {
                    format!(
                        "The cached managed JETLS installation failed verification:\n{verification_error}\nFailed to repair the managed JETLS installation:\n{installation_error}"
                    )
                } else {
                    installation_error
                }
            })
        })()
        .map_err(|error| {
            format!(
                "{error}\nIf the error persists, delete the managed JETLS storage at '{container_path}' and restart the language server."
            )
        })?;

        Self::touch_last_used(Path::new(&generation_path));
        Self::touch_last_used(Path::new(&container_path));
        Self::cleanup_managed_storage(&container_path);

        let launch_env = Self::server_launch_env(command_env, &generation_path, platform);
        Ok(zed::Command {
            command: julia_bin,
            args: Self::julia_launch_args(&args),
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
        let (platform, _) = zed::current_platform();
        let command_env = Self::command_env(&settings, worktree, platform);
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
    fn launches_julia_directly_with_the_shim_argument_protocol() {
        // Without a `--` separator, every argument goes to the JETLS app.
        assert_eq!(
            JuliaExtension::julia_launch_args(&strings(&["serve"])),
            strings(&[
                "--startup-file=no",
                "--history-file=no",
                "--threads=auto",
                "-m",
                "JETLS",
                "serve"
            ])
        );
        // Arguments before `--` go to `julia` itself, after the defaults so
        // they can override them.
        assert_eq!(
            JuliaExtension::julia_launch_args(&strings(&["--threads=1", "--", "serve"])),
            strings(&[
                "--startup-file=no",
                "--history-file=no",
                "--threads=auto",
                "--threads=1",
                "-m",
                "JETLS",
                "serve"
            ])
        );
    }

    #[test]
    fn chains_the_managed_depot_before_the_user_depots() {
        // An explicit user chain is preserved after the managed depot.
        let env = vec![("JULIA_DEPOT_PATH".to_string(), "/custom/depot:".to_string())];
        assert_eq!(
            JuliaExtension::server_depot_chain(&env, "/managed", zed::Os::Mac),
            "/managed:/custom/depot:"
        );

        let env = vec![("JULIA_DEPOT_PATH".to_string(), r"C:\custom".to_string())];
        assert_eq!(
            JuliaExtension::server_depot_chain(&env, r"C:\managed", zed::Os::Windows),
            r"C:\managed;C:\custom"
        );

        // Windows environment keys match case-insensitively.
        let env = vec![("julia_depot_path".to_string(), r"C:\custom".to_string())];
        assert_eq!(
            JuliaExtension::server_depot_chain(&env, r"C:\managed", zed::Os::Windows),
            r"C:\managed;C:\custom"
        );

        // Otherwise the default user depot is chained, with a trailing empty
        // entry appending the bundled system depots.
        let env = vec![("HOME".to_string(), "/Users/me".to_string())];
        assert_eq!(
            JuliaExtension::server_depot_chain(&env, "/managed", zed::Os::Mac),
            "/managed:/Users/me/.julia:"
        );

        // An empty user chain means the Julia default chain, not "no depot".
        let env = vec![
            ("JULIA_DEPOT_PATH".to_string(), String::new()),
            ("HOME".to_string(), "/Users/me".to_string()),
        ];
        assert_eq!(
            JuliaExtension::server_depot_chain(&env, "/managed", zed::Os::Mac),
            "/managed:/Users/me/.julia:"
        );

        // Without a resolvable home, fall back to the bundled depots only.
        assert_eq!(
            JuliaExtension::server_depot_chain(&[], "/managed", zed::Os::Mac),
            "/managed:"
        );
    }

    #[test]
    fn pins_the_depot_chain_and_load_path_for_the_server_launch() {
        let env = vec![("HOME".to_string(), "/Users/me".to_string())];
        let launch_env = JuliaExtension::server_launch_env(env, "/managed", zed::Os::Mac);
        assert_eq!(
            JuliaExtension::env_value(&launch_env, "JULIA_DEPOT_PATH", zed::Os::Mac),
            Some("/managed:/Users/me/.julia:")
        );
        assert_eq!(
            JuliaExtension::env_value(&launch_env, "JULIA_LOAD_PATH", zed::Os::Mac),
            Some("/managed/environments/apps/JETLS")
        );
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

    fn temp_container(name: &str) -> (std::path::PathBuf, String) {
        // Nest under a `jetls-depots` directory so the stale-runtime sweep in
        // `cleanup_managed_storage` stays inside the test sandbox.
        let base = std::env::temp_dir().join(format!(
            "zed-julia-test-{name}-{:x}",
            JuliaExtension::unix_nanos()
        ));
        let container = base.join(MANAGED_DEPOTS_DIR).join("runtime");
        std::fs::create_dir_all(&container).unwrap();
        (base, container.to_string_lossy().into_owned())
    }

    #[test]
    fn generation_ids_embed_the_pinned_revision() {
        let id = JuliaExtension::new_generation_id();
        let suffix = id.strip_prefix(&format!("{JETLS_REVISION}-")).unwrap();
        assert!(!suffix.is_empty());
        assert!(suffix
            .chars()
            .all(|character| character.is_ascii_hexdigit()));
    }

    #[test]
    fn publishes_and_resolves_the_current_generation() {
        let (base, container) = temp_container("publish");
        assert_eq!(JuliaExtension::read_current_generation(&container), None);

        let (generation_id, generation_path) =
            JuliaExtension::create_generation_directory(&container).unwrap();
        JuliaExtension::write_current_generation(&container, &generation_id).unwrap();
        assert_eq!(
            JuliaExtension::read_current_generation(&container),
            Some(generation_path)
        );

        // Republishing atomically points at the newer generation.
        let (new_id, new_path) = JuliaExtension::create_generation_directory(&container).unwrap();
        JuliaExtension::write_current_generation(&container, &new_id).unwrap();
        assert_eq!(
            JuliaExtension::read_current_generation(&container),
            Some(new_path)
        );

        std::fs::remove_dir_all(&base).unwrap();
    }

    #[test]
    fn rejects_invalid_current_pointers() {
        let (base, container) = temp_container("pointer");
        let pointer_path = JuliaExtension::current_pointer_path(&container);
        for generation in ["../evil", "a/b", r"a\b", ".hidden", "C:evil", ""] {
            std::fs::write(&pointer_path, format!("{{\"generation\": {generation:?}}}")).unwrap();
            assert_eq!(JuliaExtension::read_current_generation(&container), None);
        }
        std::fs::write(&pointer_path, "garbage").unwrap();
        assert_eq!(JuliaExtension::read_current_generation(&container), None);

        // A pointer to a missing generation directory is also ignored.
        std::fs::write(&pointer_path, "{\"generation\": \"missing\"}").unwrap();
        assert_eq!(JuliaExtension::read_current_generation(&container), None);

        std::fs::remove_dir_all(&base).unwrap();
    }

    #[test]
    fn reclaims_entries_only_after_their_grace() {
        const HOUR: Duration = Duration::from_secs(60 * 60);
        const DAY: Duration = Duration::from_secs(24 * 60 * 60);
        // An unknown age never removes.
        assert!(!JuliaExtension::should_remove_entry(false, None));
        // In-progress installations survive the short grace...
        assert!(!JuliaExtension::should_remove_entry(false, Some(HOUR)));
        // ...but abandoned ones are reclaimed soon after it.
        assert!(JuliaExtension::should_remove_entry(false, Some(2 * DAY)));
        // Published generations outlive the unpublished grace...
        assert!(!JuliaExtension::should_remove_entry(true, Some(2 * DAY)));
        // ...until no window has plausibly resolved them within the retention.
        assert!(JuliaExtension::should_remove_entry(true, Some(8 * DAY)));
    }

    #[test]
    fn cleanup_keeps_the_current_generation_and_fresh_entries() {
        let (base, container) = temp_container("cleanup");
        let (current_id, current_path) =
            JuliaExtension::create_generation_directory(&container).unwrap();
        JuliaExtension::write_install_stamp(&current_path, "1.12.6");
        JuliaExtension::write_current_generation(&container, &current_id).unwrap();
        let (_, fresh_path) = JuliaExtension::create_generation_directory(&container).unwrap();

        JuliaExtension::cleanup_managed_storage(&container);

        assert!(std::fs::metadata(&current_path).is_ok());
        assert!(std::fs::metadata(&fresh_path).is_ok());
        std::fs::remove_dir_all(&base).unwrap();
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
        JuliaExtension::set_env_value(
            &mut env,
            "JULIA_DEPOT_PATH",
            "managed".to_string(),
            zed::Os::Mac,
        );

        assert_eq!(
            JuliaExtension::env_value(&env, "JULIA_DEPOT_PATH", zed::Os::Mac),
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
    fn matches_environment_keys_case_insensitively_on_windows() {
        let mut env = vec![("Julia_Depot_Path".to_string(), "old".to_string())];
        assert_eq!(
            JuliaExtension::env_value(&env, "JULIA_DEPOT_PATH", zed::Os::Windows),
            Some("old")
        );
        // Elsewhere, differently cased keys are distinct variables.
        assert_eq!(
            JuliaExtension::env_value(&env, "JULIA_DEPOT_PATH", zed::Os::Mac),
            None
        );

        // A replacement must not leave a differently cased duplicate behind.
        JuliaExtension::set_env_value(
            &mut env,
            "JULIA_DEPOT_PATH",
            "managed".to_string(),
            zed::Os::Windows,
        );
        assert_eq!(
            env,
            vec![("JULIA_DEPOT_PATH".to_string(), "managed".to_string())]
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

use zed::{CodeLabel, LanguageServerId};
use zed_extension_api::{self as zed, Result};

struct JuliaExtension;

impl zed::Extension for JuliaExtension {
    fn new() -> Self {
        Self
    }

    fn language_server_command(
        &mut self,
        _language_server_id: &LanguageServerId,
        worktree: &zed::Worktree,
    ) -> Result<zed::Command> {
        let Some(julia_bin) = worktree.which("julia") else {
            return Err("Unable to find julia binary. Make sure the PATH variable contains the directory where the julia binary is located.".to_string());
        };
        Ok(zed::Command {
            command: julia_bin.to_string(),
            args: vec![
                // Ideally, zed should provide ~/.config/zed/languages/LanguageServer.jl
                // we resort to julia global environments instead.
                "--project=@zed-julia".to_string(),
                "--startup-file=no".to_string(),
                "--history-file=no".to_string(),
                "--thread=auto".to_string(),
                "-e".to_string(),
                // TODO: handle LanguageServer.jl updates.
                r#"
                import Pkg, UUIDs

                ls_uuid = UUIDs.UUID("2b0e0bc5-e4fd-59b4-8912-456d1b03d8d7")
                if !haskey(Pkg.dependencies(), ls_uuid)
                    Pkg.add(Pkg.PackageSpec(uuid=ls_uuid))
                end

                try
                    @eval using LanguageServer
                catch
                    Pkg.update()
                    @eval using LanguageServer
                end

                runserver()
                "#
                .to_string(),
            ],
            env: Default::default(),
        })
    }

    fn label_for_completion(
        &self,
        _language_server_id: &LanguageServerId,
        completion: zed::lsp::Completion,
    ) -> Option<zed::CodeLabel> {
        match completion.kind {
            Some(zed::lsp::CompletionKind::Unit) if completion.label.starts_with('\\') => {
                let text = &completion.label;
                let filter_range = if text.starts_with("\\:") && text.ends_with(":") {
                    // Completions such as \:pizza:
                    2..text.len() - 1
                } else {
                    // Unicode completions such as \lambda
                    1..text.len()
                };
                Some(CodeLabel {
                    code: completion.detail?,
                    spans: Default::default(),
                    filter_range: filter_range.into(),
                })
            }
            _ => None,
        }
    }
}

zed::register_extension!(JuliaExtension);

# Changelog

All notable user-facing changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

This file describes changes delivered by extension updates, including updates to the managed [JETLS](https://github.com/aviatesk/JETLS.jl) language server. Language-server sections link to the upstream release notes.

Changes before version 0.2.0 are recorded in the corresponding [Zed extension registry pull requests](https://github.com/zed-industries/extensions/pulls?q=is%3Apr+julia+in%3Atitle).

## Unreleased

- Commit: [`HEAD`](https://github.com/JuliaEditorSupport/zed-julia/commit/HEAD)
- Diff: [`v0.2.0...HEAD`](https://github.com/JuliaEditorSupport/zed-julia/compare/v0.2.0...HEAD)
- Pinned JETLS: <!-- Set during release preparation; do not edit by hand. -->

### Language server

<!-- Generated during release preparation; do not edit by hand. -->

### Zed extension

## v0.2.0

- Commit: [`v0.2.0`](https://github.com/JuliaEditorSupport/zed-julia/commit/v0.2.0)
- Diff: [`2ff6b4e...v0.2.0`](https://github.com/JuliaEditorSupport/zed-julia/compare/2ff6b4e...v0.2.0)
- Pinned JETLS: [`2026-09-23`](https://github.com/aviatesk/JETLS.jl/releases/tag/2026-09-23)

### Zed extension

#### Breaking

- Replaced the default [LanguageServer.jl](https://github.com/julia-vscode/LanguageServer.jl) backend with [JETLS](https://github.com/aviatesk/JETLS.jl). JETLS requires Julia 1.12.2 through 1.13, and language server settings move from `lsp.julia` to `lsp.jetls` without migration. See [Migrating to version 0.2](./README.md#migrating-to-version-02).

#### Added

- Added [automatic installation and updates](./README.md#automatic-installation-and-updates) of the pinned JETLS release in extension-private storage, including [per-project Julia selection](./README.md#julia-for-jetls), custom [launch configuration](./README.md#launch-configuration), and [server configuration](./README.md#server-configuration).
- Added built-in tasks for `Pkg.instantiate`, `Pkg.precompile`, `Pkg.update`, and `Pkg.resolve` alongside the existing `Pkg.test` task.
- Added bracket matching for block keywords such as `function`/`end` and `begin`/`end`.
- Added highlighting of struct field declarations as `@variable.member`.

#### Changed

- Renamed the built-in `julia test` task to `Julia: Pkg.jl test`. Package tasks now run from the worktree root and hide their terminals after successful completion.

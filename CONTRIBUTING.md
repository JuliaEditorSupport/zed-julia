# Contributing

**Make sure to read the following documentation:**

- [Developing Extensions](https://zed.dev/docs/extensions/developing-extensions)
- [Language Extensions](https://zed.dev/docs/extensions/languages)

## Filing issues

Before reporting an issue,
check [existing issues](https://github.com/JuliaEditorSupport/zed-julia/issues?q=is%3Aissue)
(including closed issues).

The Julia Zed extension is mostly glue code that defines how Zed should use
tree-sitter and the language server protocol with Julia. Please report issues
in the appropriate issue tracker.

### tree-sitter integration

If Zed is not highlighting something properly,
check the queries defined in: [`./languages/julia/*.scm`](./languages/julia/).

If the issue does not seem to be related to the way queries are defined,
check the [tree-sitter-julia issue tracker](https://github.com/tree-sitter/tree-sitter-julia/issues).

### Language server integration

Report issues with managed installation, Julia runtime selection, Zed settings,
or other extension integration in the
[zed-julia issue tracker](https://github.com/JuliaEditorSupport/zed-julia/issues).
If the behavior also occurs when running JETLS independently of Zed, check the
[JETLS.jl issue tracker](https://github.com/aviatesk/JETLS.jl/issues).

## Updating the pinned JETLS release

Each zed-julia release pins an exact dated JETLS release tag. Update the pin
with the release date:

```sh
./scripts/update-jetls-revision.sh YYYY-MM-DD
```

The script verifies the tag's `JETLS_VERSION` descriptor, reads the `julia`
compat entry from its `Project.toml`, and updates `JETLS_REVISION`,
`JULIA_VERSION_LOWER_BOUND`, and `JULIA_VERSION_UPPER_BOUND` in
[`src/julia.rs`](./src/julia.rs). It requires the
[GitHub CLI](https://cli.github.com/) with access to the GitHub API.

Verify the current source without changing it and run the Rust tests:

```sh
./scripts/update-jetls-revision.sh --check
cargo test --locked
```

Update the pin together with a zed-julia extension release so users receive the
new managed JETLS version through the extension update.

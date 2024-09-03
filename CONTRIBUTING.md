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

If you find an issue with the language server,
check the [LanguageServer.jl issue tracker](https://github.com/julia-vscode/LanguageServer.jl/issues).

# Zed Julia

This extension adds support for the [Julia](https://julialang.org/) language in
the [zed](https://zed.dev) editor.

### Quick links

* [Contributing](./CONTRIBUTING.md)
* [Installing Julia / Zed / Zed Julia extension](#installing-julia--zed--zed-julia-extension)
* [Configuring the Julia executable for tasks](#configuring-the-julia-executable-for-tasks)
* [Running code in the REPL](#running-code-in-the-repl)
* [Using Zed in the REPL](#using-zed-in-the-repl)
* [Changing settings of the LanguageServer](#changing-settings-of-the-languageserver)
* [Customizing syntax highlighting](#customizing-syntax-highlighting)

### Installing Julia / Zed / Zed Julia extension

1. Install Julia for your platform: https://julialang.org/downloads/
2. Install Zed for your platform: https://zed.dev/download
3. Start Zed.
4. Inside Zed, go to the extensions view by
executing the ``zed: extensions`` command (click Zed->Extensions).
5. In the extensions view, simply search for the term ``julia`` in the search box, then select the extension named ``Julia`` and click the install button. You might have to restart Zed after this step.

The Julia Zed extension looks for your Julia binary in the standard locations.
Make sure that the Julia binary is on your ``PATH``.

### Configuring the Julia executable for tasks

By default, Zed tasks (like running tests) use the `julia` command from your PATH.
You can customize which Julia executable is used by setting the `julia` environment variable:

1. **In your shell configuration** (`.bashrc`, `.zshrc`, etc.):
   ```bash
   export julia="/path/to/custom/julia"
   ```

2. **When launching Zed from the terminal**:
   ```bash
   julia="/path/to/custom/julia" zed .
   ```

3. **Using direnv** (automatically supported by Zed):
   - Create a `.envrc` file in your project root with:
     > .envrc
     ```
     JULIA_HOME="path/to/julia/directory"
     PATH_add "$JULIA_HOME/bin"
     export julia="$JULIA_HOME/bin/julia"
     ```
   - Run `direnv allow` to approve the file

This allows you to use different Julia versions for different projects or to
specify a Julia installation that's not on your PATH.

### Running code in the REPL

This section describes how to select Julia code in the editor and run it in Zed's integrated
terminal. This is more of a workaround than a full integration. Currently, there is no
_inline code execution_ as in VSCode. On the other hand, the Language Server is not required
to make this work.

1.  Open a .jl file in the editor.

2.  From the Command Palette, run `open in terminal`. This opens a new terminal in the
    worktree root (where the Project.toml lives). You can also right-click in the editor and
    use the context menu or press ``ctrl-shift-` `` as defined in the json example below.

3.  In the terminal, start the REPL with `julia --project`.

4.  Now it's time to select some code in the editor, copy it to the clipboard, paste it into
    the terminal, execute it, and go back to the editor. To make that less tedious, add one
    or more of the following key bindings. Change the `ctrl-shift-f10/11/12` combinations
    to your liking.

    Note: interacting with the terminal requires to send keystrokes. In the examples,
    `cmd-v` is used to paste code. Please adjust this binding for your operating system.

    ```jsonc
    // Zed key map file, usually ~/.config/zed/keymap.json
    [
      {
        // Set the focus back to the editor without hiding the terminal.
        // This is an auxiliary binding used by other bindings.
        "context": "Terminal",
        "bindings": { "ctrl-shift-`": "terminal_panel::ToggleFocus" }
      },
      {
        "context": "Editor && mode == full",
        "bindings": {
          // Open a new terminal and change to the worktree root directory.
          "ctrl-shift-`": "workspace::OpenInTerminal",

          // Execute the whole line the cursor is on and move the cursor to the next line.
          // Invoke this binding repeately to run line by line.
          "ctrl-shift-f10": [
            "action::Sequence",
            [
              "editor::SelectLine",
              "editor::Copy",
              "editor::MoveRight",
              ["workspace::SendKeystrokes", "ctrl-` cmd-v ctrl-shift-`"]
            ]
          ],

          // Execute the enclosing top level block e.g., a function definition.
          // Note the additional keystroke "enter" to actually execute the code.
          "ctrl-shift-f11": [
            "action::Sequence",
            [
              "editor::SelectEnclosingSymbol",
              "editor::CopyAndTrim",
              ["workspace::SendKeystrokes", "ctrl-` cmd-v enter ctrl-shift-`"]
            ]
          ],

          // Execute the paragraph (a block surrounded by blank lines).
          "ctrl-shift-f12": [
            "action::Sequence",
            [
              "editor::MoveToStartOfParagraph",
              "editor::SelectToEndOfParagraph",
              "editor::Copy",
              ["workspace::SendKeystrokes", "ctrl-` cmd-v ctrl-shift-`"]
            ]
          ]
        }
      }
    ]
    ```

### Using Zed in the REPL

Zed is currently not on the list of Julia's predefined editors. You can add it to your `~/.julia/config/startup.jl`:

```julia
atreplinit() do repl
    InteractiveUtils.define_editor("zed") do cmd, path, line, column
        `$cmd $path:$line:$column`
    end
end
```

Set the environment variable EDITOR (or VISUAL or JULIA_EDITOR, whatever you use) to `zed --wait`. Then, using `InteractiveUtils.edit` etc. will open the document in Zed.

### Changing settings of the LanguageServer

The Julia LS can be customized by adding a section to your `~/.config/zed/settings.json`. Example: don't show diagnostic messages of type "missing references" with:

```json
{
  "lsp": {
    "julia": {
      "settings": {
        "julia.lint.missingrefs": "none"
      }
    }
  }
}
```

We will add autocompletions for the available settings later (there is some groundwork missing in Zed). For now, have a look at the `lint` keys in 
[julia-vscode](https://github.com/julia-vscode/julia-vscode/blob/8f8d879dc62dee1658115c40dc4e156e9c0cffe4/package.json#L874).

### Customizing syntax highlighting

You can change the foreground color and text attributes of syntax tokens in your `~/.config/zed/settings.json`, for instance:

```json
{
  "experimental.theme_overrides": {
    "syntax": {
      "comment.doc": {
        "font_style": "italic"
      },
      "function.definition": {
        "color": "#0000AA",
        "font_weight": 700
      }
    }
  }
}
```

See [Syntax Highlighting and Themes](https://zed.dev/docs/configuring-languages#syntax-highlighting-and-themes) and [Tree-sitter Queries](https://zed.dev/docs/extensions/languages#tree-sitter-queries) for further details.

Syntax tokens are called *captures* in tree-sitter jargon. The following table lists all captures provided by zed-julia. Some captures have default values (defined in [Zed's color themes](https://github.com/zed-industries/zed/blob/main/assets/themes/)) and the other captures fall back to one of the defaults. Depending on your color theme, some captures may be set to the editor's foreground color or to a very similar one. In this case, try to assign a different color to improve the contrast. 

| Capture | Is there a default value? | Note/Example | 
| ------- | ------------------------- | ------------ |
| boolean | yes |
| comment | yes | line or block comment |
| comment.doc | yes | docstring |
| constant.builtin | no, falls back to constant | core julia built-in |
| function.builtin | no, falls back to function | core julia built-in |
| function.call | no, falls back to function | name of the called function |
| function.definition | no, falls back to function | name of the defined function |
| function.macro | no, falls back to function | name of the macro |
| keyword | yes |
| keyword.conditional | no, falls back to keyword | `if`, `else` |
| keyword.conditional.ternary | no, falls back to keyword | `? :` |
| keyword.exception | no, falls back to keyword | `try`, `catch` |
| keyword.function | no, falls back to keyword | `function`, `do`, short function definition: `=` |
| keyword.import | no, falls back to keyword | `im/export`, `using`, module definition |
| keyword.operator | no, falls back to keyword | `in`, `isa`, `where` |
| keyword.repeat | no, falls back to keyword | `for`, `while` |
| keyword.return | no, falls back to keyword | `return` |
| number | yes |
| number.float | no, falls back to number |
| operator | yes |
| punctuation.bracket | yes | `()`, `[]`, `{}` |
| punctuation.delimiter | yes | `,`, `;`, `::` |
| punctuation.special | yes | `.`, `...`, string interpolation `$` |
| string | yes |
| string.escape | yes | escape sequence |
| string.special | yes | command literal |
| string.special.symbol | yes | quote expression |
| type | yes |
| type.builtin | no, falls back to type | core julia built-in |
| type.definition | no, falls back to type |
| variable | yes |
| variable.builtin | no, falls back to variable | core julia built-in: `begin` and `end` in indices |
| variable.member | no, falls back to variable | example: in `foo.bar`, the member is `bar` |

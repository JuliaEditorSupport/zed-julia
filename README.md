# Zed Julia

This extension adds support for the [Julia](https://julialang.org/) language in
the [zed](https://zed.dev) editor.


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

### Contributing

See [this document](./CONTRIBUTING.md).


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
| punctuation.delimiter | yes | `,`, `;` |
| punctuation.special | yes | string interpolation: `$()` |
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

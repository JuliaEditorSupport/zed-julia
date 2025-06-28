; `@start.xxx` marks where these clauses start for `valid_after` matching in config.toml

[
  (struct_definition
    "struct" @start.struct
    "end" @end)
  (macro_definition
    "macro" @start.macro
    "end" @end)
  (function_definition
    "function" @start.function
    "end" @end)
  (compound_statement
    "begin" @start.begin
    "end" @end)
  (if_statement
    "if" @start.if
    "end" @end)
  (try_statement
    "try" @start.try
    "end" @end)
  (for_statement
    "for" @start.for
    "end" @end)
  (while_statement
    "while" @start.while
    "end" @end)
  (let_statement
    "let" @start.let
    "end" @end)
  (quote_statement
    "quote" @start.quote
    "end" @end)
  (do_clause
    "do" @start.do
    "end" @end)
  (assignment)
  (for_binding)
  (call_expression)
  (parenthesized_expression)
  (tuple_expression)
  (comprehension_expression)
  (matrix_expression)
  (vector_expression)
] @indent

(_ "[" "]" @end) @indent
(_ "{" "}" @end) @indent
(_ "(" ")" @end) @indent

[
  (else_clause)
  (elseif_clause)
  (catch_clause)
  (finally_clause)
] @outdent

; doc macro docstrings:
; @doc "..." x
((macrocall_expression
  (macro_identifier "@" (identifier)) @_macro
  (macro_argument_list
    .
    (string_literal) @content))
  (#eq? @_macro "@doc")
  (#set! "language" "markdown"))

; docstrings preceding documentable elements at the top of a source file:
((source_file
  (string_literal) @content
  .
  [
    (assignment)
    (const_statement)
    (global_statement)
    (abstract_definition)
    (function_definition)
    (macro_definition)
    (module_definition)
    (struct_definition)
    (macrocall_expression) ; Covers things like @kwdef struct X ... end
    (identifier)
    (open_tuple
      (identifier))
  ])
  (#set! "language" "markdown"))

; docstrings preceding documentable elements at the top of a module:
((module_definition
  (string_literal) @content
  .
  [
    (assignment)
    (const_statement)
    (global_statement)
    (abstract_definition)
    (function_definition)
    (macro_definition)
    (module_definition)
    (struct_definition)
    (macrocall_expression) ; Covers things like @kwdef struct X ... end
    (identifier)
    (open_tuple
      (identifier))
  ])
  (#set! "language" "markdown"))

; Markdown Language Injection
((prefixed_string_literal
  prefix: (identifier) @_prefix) @content
  (#eq? @_prefix "md")
  (#set! "language" "markdown"))

; Regex Language Injection
((prefixed_string_literal
  prefix: (identifier) @_prefix) @content
  (#eq? @_prefix "r")
  (#set! "language" "regex"))

; SQL Language Injection
((prefixed_command_literal
  prefix: (identifier) @_prefix) @content
  (#eq? @_prefix "sql")
  (#set! "language" "sql"))

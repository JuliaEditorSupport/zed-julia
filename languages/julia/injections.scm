; doc macro docstrings:
; @doc "..." x
((macrocall_expression
  (macro_identifier "@" (identifier)) @function.macro
  (macro_argument_list
    .
    (string_literal) @content))
  (#eq? @function.macro "@doc")
  (#set! "language" "markdown"))


; docstrings preceding documentable elements at the top of a source file:
((source_file
  ; The Docstring:
  [
    (string_literal) @content
    ; Workaroud: Find strings stolen as the last argument to a preceding macro
    ; https://github.com/tree-sitter/tree-sitter-julia/issues/150
    (macrocall_expression
      (macro_argument_list
      (_)+
      (string_literal) @content .))
  ]
  .
  ; The documentable element:
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
  (#match? @content "^\"\"\"")
  (#set! "language" "markdown"))

; docstrings preceding documentable elements at the top of a module:
((module_definition
  ; The Docstring:
  [
    (string_literal) @content
    ; Workaroud: Find strings stolen as the last argument to a preceding macro
    ; https://github.com/tree-sitter/tree-sitter-julia/issues/150
    (macrocall_expression
      (macro_argument_list
      (_)+
      (string_literal) @content .))
  ]
  .
  ; The documentable element:
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
  (#match? @content "^\"\"\"")
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

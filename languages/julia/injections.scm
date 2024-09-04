; Inject markdown in docstrings
; Be aware that this will clutter the outline view with markdown headers.
((string_literal) @content
  .
  [
    (module_definition)
    (abstract_definition)
    (struct_definition)
    (function_definition)
    (assignment)
    (const_statement)
  ]
  (#match? @content "^\"\"\"")
  (#set! "language" "markdown"))

((macrocall_expression
  (macro_identifier "@" (identifier)) @function.macro
  (macro_argument_list
    .
    (string_literal) @content))
  (#eq? @function.macro "@doc")
  (#set! "language" "markdown"))

((source_file
  (string_literal) @content
  .
  [
    (identifier)
    (macrocall_expression)
    (open_tuple
      (identifier))
  ])
  (#set! "language" "markdown"))

((module_definition
  (string_literal) @content
  .
  [
      (identifier)
      (macrocall_expression)
      (open_tuple
        (identifier))
  ])
  (#set! "language" "markdown"))

((module_definition
  (macrocall_expression
    (macro_argument_list
      (_)+
      (string_literal) @content .))
  .
  [
    (identifier)
    (macrocall_expression)
    (module_definition)
    (abstract_definition)
    (struct_definition)
    (function_definition)
    (assignment)
    (const_statement)
    (open_tuple
      (identifier))
  ])
  (#set! "language" "markdown"))

((source_file
  (macrocall_expression
    (macro_argument_list
      (_)+
      (string_literal) @content .))
  .
  [
    (identifier)
    (macrocall_expression)
    (module_definition)
    (abstract_definition)
    (struct_definition)
    (function_definition)
    (assignment)
    (const_statement)
    (open_tuple
      (identifier))
  ])
  (#set! "language" "markdown"))

((prefixed_string_literal
  prefix: (identifier) @_prefix) @content
  (#eq? @_prefix "r")
  (#set! "language" "regex"))

((prefixed_command_literal
  prefix: (identifier) @_prefix) @content
  (#eq? @_prefix "sql")
  (#set! "language" "sql"))

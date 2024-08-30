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
    (open_tuple
      (identifier))
  ])
  (#set! "language" "markdown"))

((module_definition
  (string_literal) @content
  .
  [
      (identifier)
      (open_tuple
        (identifier))
  ])
  (#set! "language" "markdown"))

([
  (line_comment)
  (block_comment)
] @injection.content
  (#set! "language" "comment"))

((prefixed_string_literal
  prefix: (identifier) @_prefix) @content
  (#eq? @_prefix "r")
  (#set! "language" "regex"))

((prefixed_command_literal
  prefix: (identifier) @_prefix) @content
  (#eq? @_prefix "sql")
  (#set! "language" "sql"))

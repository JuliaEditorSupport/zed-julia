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
    (open_tuple
      (identifier))
    (identifier)
  ]
  (#match? @content "^\"\"\"")
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

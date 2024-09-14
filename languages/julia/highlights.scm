; Guidelines:
; - No highlighting is better than ambiguous highlighting.
; - Only names defined in `Core` should be highlighted as `builtin`.
;
; Identifiers
(identifier) @variable

(field_expression
  (identifier) @variable.member .)

; Symbols
(quote_expression
  ":" @string.special.symbol
  [
    (identifier)
    (operator)
  ] @string.special.symbol)

; Function calls
(call_expression
  (identifier) @function.call)

(call_expression
  (field_expression
    (identifier) @function.call .))

(broadcast_call_expression
  (identifier) @function.call)

(broadcast_call_expression
  (field_expression
    (identifier) @function.call .))

; TODO
; Function calls in pipes
(binary_expression
  (_)
  (operator) @_pipe
  (identifier) @function.call
  (#any-of? @_pipe "|>" ".|>"))

; Macros
(macro_identifier) @function.macro

; TODO
; Required to highlight the macro name, not just the @
(macro_identifier
  (identifier) @function.macro)

(macro_definition
  (signature
    (call_expression
      .
      (identifier) @function.macro)))

; Built-in functions
; filter(name -> Base.eval(Core, name) isa Core.Builtin, names(Core))
((identifier) @function.builtin
  (#any-of? @function.builtin
    "applicable" "fieldtype" "getfield" "getglobal" "invoke" "isa" "isdefined" "modifyfield!"
    "modifyglobal!" "nfields" "replacefield!" "replaceglobal!" "setfield!" "setfieldonce!"
    "setglobal!" "setglobalonce!" "swapfield!" "swapglobal!" "throw" "tuple" "typeassert" "typeof"))

; TODO
; Parameters, I think we can drop both:
(argument_list
  (identifier) @variable.parameter)

; TODO continued
(function_expression
  .
  (identifier) @variable.parameter) ; Single parameter arrow functions

; Type definitions
(abstract_definition
  name: (identifier) @type.definition) @keyword

(primitive_definition
  name: (identifier) @type.definition) @keyword

(struct_definition
  name: (identifier) @type.definition)

(type_clause
  [
    (identifier) @type
    (field_expression
      (identifier) @type .)
  ])

; Type annotations
(parametrized_type_expression
  [
   (identifier) @type
   (field_expression
     (identifier) @type .)
  ]
  (curly_expression
    (_) @type))

(type_parameter_list
  (identifier) @type)

(typed_expression
  (identifier) @type .)

(unary_typed_expression
  (identifier) @type .)

(where_clause
  (identifier) @type)

(where_clause
  (curly_expression
    (_) @type))

; Built-in types
; filter(name -> typeof(Base.eval(Core, name)) in [DataType, UnionAll], names(Core))
((identifier) @type.builtin
  (#any-of? @type.builtin
    "AbstractArray" "AbstractChar" "AbstractFloat" "AbstractString" "Any" "ArgumentError" "Array"
    "AssertionError" "Bool" "BoundsError" "Char" "ConcurrencyViolationError" "Cvoid" "DataType"
    "DenseArray" "DivideError" "DomainError" "ErrorException" "Exception" "Expr" "Float16" "Float32"
    "Float64" "Function" "GlobalRef" "IO" "InexactError" "InitError" "Int" "Int128" "Int16" "Int32"
    "Int64" "Int8" "Integer" "InterruptException" "LineNumberNode" "LoadError" "Method"
    "MethodError" "Module" "NTuple" "NamedTuple" "Nothing" "Number" "OutOfMemoryError"
    "OverflowError" "Pair" "Ptr" "QuoteNode" "ReadOnlyMemoryError" "Real" "Ref" "SegmentationFault"
    "Signed" "StackOverflowError" "String" "Symbol" "Task" "Tuple" "Type" "TypeError" "TypeVar"
    "UInt" "UInt128" "UInt16" "UInt32" "UInt64" "UInt8" "UndefInitializer" "UndefKeywordError"
    "UndefRefError" "UndefVarError" "Union" "UnionAll" "Unsigned" "VecElement" "WeakRef"))

; Keywords
[
  "const"
  "global"
  "local"
] @keyword

(compound_statement
  [
    "begin"
    "end"
  ] @keyword)

(quote_statement
  [
    "quote"
    "end"
  ] @keyword)

(let_statement
  [
    "let"
    "end"
  ] @keyword)

(if_statement
  [
    "if"
    "end"
  ] @keyword.conditional)

(elseif_clause
  "elseif" @keyword.conditional)

(else_clause
  "else" @keyword.conditional)

(ternary_expression
  [
    "?"
    ":"
  ] @keyword.conditional.ternary)

(try_statement
  [
    "try"
    "end"
  ] @keyword.exception)

(catch_clause
  "catch" @keyword.exception)

(finally_clause
  "finally" @keyword.exception)

(for_statement
  [
    "for"
    "end"
  ] @keyword.repeat)

(for_binding
  "outer" @keyword.repeat)

; comprehensions
(for_clause
  "for" @keyword.repeat)

(if_clause
  "if" @keyword.conditional)

(while_statement
  [
    "while"
    "end"
  ] @keyword.repeat)

[
  (break_statement)
  (continue_statement)
] @keyword.repeat

(function_definition
  [
    "function"
    "end"
  ] @keyword.function)

(do_clause
  [
    "do"
    "end"
  ] @keyword.function)

(macro_definition
  [
    "macro"
    "end"
  ] @keyword)

(return_statement
  "return" @keyword.return)

(module_definition
  [
    "module"
    "baremodule"
    "end"
  ] @keyword.import)

(export_statement
  "export" @keyword.import)

(import_statement
  [
    "import"
    "using"
  ] @keyword.import)

(import_alias
  "as" @keyword.import)

(selected_import
  ":" @punctuation.delimiter)

(struct_definition
  [
    "mutable"
    "struct"
    "end"
  ] @keyword.type)


; Operators & Punctuation
[
  "->"
  "="
  "∈"
  (operator)
] @operator

(adjoint_expression
  "'" @operator)

(range_expression
  ":" @operator)

[
  "."
  "..."
  "::"
] @punctuation.special

[
  ","
  ";"
] @punctuation.delimiter

[
  "("
  ")"
  "["
  "]"
  "{"
  "}"
] @punctuation.bracket

; TODO
; Interpolated variables and complex expressions
(string_interpolation
[
  "$"
  "("
  ")"
] @punctuation.special)

; TODO
; Match the dot in the @. macro
(macro_identifier
  (operator) @function.macro (#eq? @function.macro "."))

; TODO
; Function definitions like `function foo() ...` or `function Base.show() ...`
(signature
  (call_expression
    [
      (identifier) @function.definition
      (field_expression (identifier) @function.definition .)
    ]))

; TODO
; Short function definitions like `foo(x) = 2x`
(assignment
  .
  [
    (call_expression (identifier) @function.definition)
    (typed_expression . (call_expression (identifier) @function.definition))
    (where_expression . (call_expression (identifier) @function.definition))
    (where_expression . (typed_expression . (call_expression (identifier) @function.definition)))
    (call_expression (field_expression (identifier) @function.definition .))
    (typed_expression . (call_expression (field_expression (identifier) @function.definition .)))
    (where_expression . (call_expression (field_expression (identifier) @function.definition .)))
    (where_expression . (typed_expression . (call_expression (field_expression (identifier) @function.definition .))))
  ]
  (operator) @keyword.function)

; Keyword operators
((operator) @keyword.operator
  (#any-of? @keyword.operator "in" "isa"))

(for_binding
  "in" @keyword.operator)

(where_clause
  "where" @keyword.operator)

(where_expression
  "where" @keyword.operator)

; Built-in constants
((identifier) @constant.builtin
  (#any-of? @constant.builtin "nothing" "missing"))

; begin/end indices
((identifier) @variable.builtin
  (#any-of? @variable.builtin "begin" "end")
  (#has-ancestor? @variable.builtin index_expression))

((identifier) @variable.builtin
  (#any-of? @variable.builtin "begin" "end")
  (#has-ancestor? @variable.builtin range_expression))

; Literals
(boolean_literal) @boolean

(integer_literal) @number

(float_literal) @number.float

((identifier) @number.float
  (#any-of? @number.float "NaN" "NaN16" "NaN32" "Inf" "Inf16" "Inf32"))

; TODO: Substitute NVIM's @character with Zed's @string
(character_literal) @string

(escape_sequence) @string.escape

(string_literal) @string

(prefixed_string_literal
  prefix: (identifier) @function.macro) @string

(command_literal) @string.special

(prefixed_command_literal
  prefix: (identifier) @function.macro) @string.special

; doc macro docstrings:
; @doc "..." x
((macrocall_expression
  (macro_identifier "@" (identifier)) @function.macro
  (macro_argument_list
    .
    (string_literal) @comment.doc))
  (#eq? @function.macro "@doc"))

; docstrings preceding documentable elements at the top of a source file:
((source_file
  ; The Docstring:
  [
    (string_literal) @comment.doc
    ; Workaroud: Find strings stolen as the last argument to a preceding macro
    ; https://github.com/tree-sitter/tree-sitter-julia/issues/150
    (macrocall_expression
      (macro_argument_list
      (_)+
      (string_literal) @comment.doc .))
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
  (#match? @comment.doc "^\"\"\""))

; docstrings preceding documentable elements at the top of a module:
((module_definition
  ; The Docstring:
  [
    (string_literal) @comment.doc
    ; Workaroud: Find strings stolen as the last argument to a preceding macro
    ; https://github.com/tree-sitter/tree-sitter-julia/issues/150
    (macrocall_expression
      (macro_argument_list
      (_)+
      (string_literal) @comment.doc .))
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
  (#match? @comment.doc "^\"\"\""))

[
  (line_comment)
  (block_comment)
] @comment

; Most content in this file is borrowed from the reference queries in
; https://github.com/tree-sitter/tree-sitter-julia/blob/master/queries/highlights.scm
;
; Search for "Zed" to see changes and additions. For instance, some captures
; have different names in Zed and in the reference which is based on Neovim.
;
; Please mark future deviations from the reference with "Zed" when making
; changes here.

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

; Zed - added: Function calls in pipes
(binary_expression
  (_)
  (operator) @_pipe
  (identifier) @function.call
  (#any-of? @_pipe "|>" ".|>"))

; Macros
(macro_identifier
  "@" @function.macro
  (_) @function.macro)

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

; Type definitions
(type_head (_) @type.definition)

; Type annotations
(parametrized_type_expression
  [
   (identifier) @type
   (field_expression
     (identifier) @type .)
  ]
  (curly_expression
    (_) @type))

(typed_expression
  (identifier) @type .)

(unary_typed_expression
  (identifier) @type .)

(where_expression
  (_) @type .)

(binary_expression
  (_) @type
  (operator) @operator
  (_) @type
  (#any-of? @operator "<:" ">:"))

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

(public_statement
  "public" @keyword.import)

(import_statement
  "import" @keyword.import)

(using_statement
  "using" @keyword.import)

(import_alias
  "as" @keyword.import)

(selected_import
  ":" @punctuation.delimiter)

(struct_definition
  [
    "mutable"
    "struct"
    "end"
  ] @keyword) ; Zed - changed `@keyword.type` to `@keyword`

(abstract_definition
  [
    "abstract"
    "type"
    "end"
  ] @keyword.type)

(primitive_definition
  [
    "primitive"
    "type"
    "end"
  ] @keyword.type)

; Operators & Punctuation
(operator) @operator

(adjoint_expression
  "'" @operator)

(range_expression
  ":" @operator)

(arrow_function_expression
  "->" @operator)

[
  "."
  "..."
  "::"
] @punctuation

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

; Zed - added: Interpolated variables and expressions in parentheses
(string_interpolation
[
  "$"
  "("
  ")"
] @punctuation.special)

; Zed - added: Match the dot in the @. macro
(macro_identifier
  "@"
  (operator "." @function.macro))

; Zed - added: Function definitions
; (1) `function foo end` after docstrings
; (2) `function foo() ... end`
; (3) `function Base.show() ... end`
(function_definition
  (signature
    .
    [
      (identifier) @function.definition
      (call_expression (identifier) @function.definition)
      (call_expression (field_expression (identifier) @function.definition .))
    ]))

; Zed - added: Short function definitions like `foo(x) = 2x`
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

(where_expression
  "where" @keyword.operator)

; Built-in constants
((identifier) @constant.builtin
  (#any-of? @constant.builtin "nothing" "missing"))

((identifier) @variable.builtin
  (#any-of? @variable.builtin "begin" "end")
  (#has-ancestor? @variable.builtin index_expression))

; Literals
(boolean_literal) @boolean

(integer_literal) @number

(float_literal) @number.float

((identifier) @number.float
  (#any-of? @number.float "NaN" "NaN16" "NaN32" "Inf" "Inf16" "Inf32"))

(character_literal) @string ; Zed - changed `@character` to `@string`

(escape_sequence) @string.escape

(string_literal) @string

(prefixed_string_literal
  prefix: (identifier) @function.macro) @string

(command_literal) @string.special

(prefixed_command_literal
  prefix: (identifier) @function.macro) @string.special

; Zed - modified queries for docstrings (3 queries):

; (1) doc macro docstrings:
; @doc "..." x
((macrocall_expression
  (macro_identifier "@" (identifier)) @function.macro
  (macro_argument_list
    .
    [(string_literal) (prefixed_string_literal)] @comment.doc))
  (#eq? @function.macro "@doc"))

; (2) docstrings preceding documentable elements at the top of a source file:
(source_file
  (string_literal) @comment.doc
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

; (3) docstrings preceding documentable elements at the top of a module:
(module_definition
  (string_literal) @comment.doc
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

; (4) struct field docstrings:
(struct_definition
  (string_literal) @comment.doc
  .
  [(identifier) (typed_expression)])

[
  (line_comment)
  (block_comment)
] @comment

(using_statement
  "using" @context
  [
   (selected_import (_) @name ":" @context)
   (( [(identifier) (scoped_identifier) (import_path)] @name  "," @context)*
      [(identifier) (scoped_identifier) (import_path)] @name)
  ]) @item

(import_statement
  "import" @context
  [
   (selected_import (_) @name ":" @context)
   (( [(identifier) (scoped_identifier) (import_path)] @name  "," @context)*
      [(identifier) (scoped_identifier) (import_path)] @name)
  ]) @item

(module_definition
  ["module" "baremodule"] @context
  name: (identifier) @name) @item

(abstract_definition
  "abstract" @context
  "type" @context
  (type_head
    (binary_expression
      .
      (identifier) @name))) @item

(primitive_definition
  "primitive" @context
  "type" @context
  (type_head
    (binary_expression
      .
      (identifier) @name))) @item

(struct_definition
  "mutable"? @context
  "struct" @context
  (type_head) @name) @item

(function_definition
  "function" @context
  (signature
    (call_expression
      [
        (identifier) @name ; match foo()
        (field_expression _+ @context (identifier) @name .) ; match Base.foo()
      ]
      (argument_list)? @context)
    (_)* @context ; match the rest of the signature e.g., return_type and/or where_clause
  )) @item

; Match short function definitions like foo(x) = 2x.
; These don't have signatures so, we need to match eight different nested combinations
; of call_expressions with return types and/or where clauses.
(assignment
  .
  [
    ; match `foo()` or `foo()::T` or `foo() where...` or `foo()::T where...`
    (call_expression (identifier) @name (argument_list) @context)
    (typed_expression . (call_expression (identifier) @name (argument_list) @context) _+ @context)
    (where_expression . (call_expression (identifier) @name (argument_list) @context) _+ @context)
    (where_expression . (typed_expression . (call_expression (identifier) @name (argument_list) @context) _+ @context) _+ @context)
    ; match `Base.foo()` or `Base.foo()::T` or `Base.foo() where...` or `Base.foo()::T where...`
    (call_expression (field_expression _+ @context (identifier) @name .) (argument_list) @context)
    (typed_expression . (call_expression (field_expression _+ @context (identifier) @name .) (argument_list) @context) _+ @context)
    (where_expression . (call_expression (field_expression _+ @context (identifier) @name .) (argument_list) @context) _+ @context)
    (where_expression . (typed_expression . (call_expression (field_expression _+ @context (identifier) @name .) (argument_list) @context) _+ @context) _+ @context)
  ]) @item

(macro_definition
  "macro" @context
  (signature
    (call_expression
      [
        (identifier) @name ; match foo()
        (field_expression _+ @context (identifier) @name .) ; match Base.foo()
      ]
      (argument_list)? @context)
    (_)* @context ; match the rest of the signature e.g., return_type
  )) @item

(const_statement
  "const" @context
  (assignment
    (_) @name
    (operator)
    (_))) @item

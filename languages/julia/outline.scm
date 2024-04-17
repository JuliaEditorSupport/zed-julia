(import_statement
  ["using" "import"] @context
  [
   (selected_import (_) @name ":" @context)
   (( [(identifier) (scoped_identifier) (import_path)] @name  "," @context)*
      [(identifier) (scoped_identifier) (import_path)] @name)
  ]) @item

(module_definition
  ["module" "baremodule"] @context
  name: (identifier) @name) @item

(primitive_definition
  "primitive" @context
  "type" @context
  name: (identifier) @name) @item

(abstract_definition
  "abstract" @context
  "type" @context
  name: (identifier) @name
  (type_clause)? @context) @item

(function_definition
  "function" @context
  (signature [
    (identifier) @name
    (typed_expression
      (call_expression (_) @name (argument_list) @context) "::" @context (_) @context)
    (call_expression (_) @name (argument_list) @context)
  ]
    (unary_typed_expression)? @context
  )
  (type_parameter_list)? @context
  (where_clause)? @context) @item

(assignment
  [
   (call_expression (_) @name (argument_list) @context)
   (where_expression (call_expression (_) @name (argument_list) @context) "where" @context (_) @context)
   (typed_expression
     (call_expression (_) @name (argument_list) @context) "::" @context (_) @context)
  ]) @item

(macro_definition
  "macro" @context
  (signature [
    (identifier) @name
    (typed_expression
      (call_expression (_) @name (argument_list) @context) "::" @context (_) @context)
    (call_expression (_) @name (argument_list) @context)
  ])
  ) @item

(struct_definition
  "mutable"? @context
  "struct" @context
  name: (_) @name
  (type_parameter_list)? @context) @item

(const_statement
  "const" @context
  (assignment
    (_) @name
    (operator)
    (_))) @item

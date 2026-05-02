("(" @open ")" @close)
("[" @open "]" @close)
("{" @open "}" @close)

; No queries are registered for `"` / `"""` / `` ` `` / ``` ``` ``` /
; `'` delimiters. tree-sitter-julia tokenizes the *opening* delimiter as
; an anonymous node, but the *closing* delimiter is consumed by an
; external scanner that emits the hidden `_end_str` / `_end_cmd` tokens,
; which are not addressable from queries — there is no close-side node
; to pair with the open. `character_literal` is wrapped in `token(...)`
; in the grammar, so it is a single atomic terminal and the inner `'`s
; are not separate nodes either.

((function_definition
  "function" @open
  "end" @close)
  (#set! rainbow.exclude))

((macro_definition
  "macro" @open
  "end" @close)
  (#set! rainbow.exclude))

((struct_definition
  "struct" @open
  "end" @close)
  (#set! rainbow.exclude))

; Pair `mutable` with `end` so that placing the cursor on `mutable` in
; `mutable struct ... end` highlights/jumps to the matching `end`. The
; `struct`/`end` pair above still wins when the cursor is past `struct`,
; because `innermost_enclosing_bracket_ranges` prefers the smaller pair.
; The same idea applies to `abstract type` / `primitive type` below.
((struct_definition
  "mutable" @open
  "end" @close)
  (#set! rainbow.exclude))

((abstract_definition
  "abstract" @open
  "end" @close)
  (#set! rainbow.exclude))

((abstract_definition
  "type" @open
  "end" @close)
  (#set! rainbow.exclude))

((primitive_definition
  "primitive" @open
  "end" @close)
  (#set! rainbow.exclude))

((primitive_definition
  "type" @open
  "end" @close)
  (#set! rainbow.exclude))

((typegroup_definition
  "typegroup" @open
  "end" @close)
  (#set! rainbow.exclude))

((module_definition
  "module" @open
  "end" @close)
  (#set! rainbow.exclude))

((module_definition
  "baremodule" @open
  "end" @close)
  (#set! rainbow.exclude))

((compound_statement
  "begin" @open
  "end" @close)
  (#set! rainbow.exclude))

((quote_statement
  "quote" @open
  "end" @close)
  (#set! rainbow.exclude))

((let_statement
  "let" @open
  "end" @close)
  (#set! rainbow.exclude))

((if_statement
  "if" @open
  "end" @close)
  (#set! rainbow.exclude))

((try_statement
  "try" @open
  "end" @close)
  (#set! rainbow.exclude))

((for_statement
  "for" @open
  "end" @close)
  (#set! rainbow.exclude))

((while_statement
  "while" @open
  "end" @close)
  (#set! rainbow.exclude))

((do_clause
  "do" @open
  "end" @close)
  (#set! rainbow.exclude))

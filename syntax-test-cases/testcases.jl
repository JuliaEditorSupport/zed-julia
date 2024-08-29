# (module_definition)
"""
This _should_ have `markdown` injected!
"""
module A end

# (abstract_definition)
"""
This _should_ have `markdown` injected!
"""
abstract type AbstractT end

# (struct_definition)
"""
This _should_ have `markdown` injected!
"""
struct S end

# (function_definition)
"""
This _should_ have `markdown` injected!
"""
function f end

# (assignment)
"""
This _should_ have `markdown` injected!
"""
x = 73

# (const_statement)
"""
This _should_ have `markdown` injected!
"""
const y = 42

# (macrocall_expression) with (macro_identifier) eq. "@doc"
@doc "This _should_ have `markdown` injected!" x

# (macrocall_expression) with (macro_identifier) not eq. "@doc"
@info "This should _not_ have `markdown` injected!" x

# (source_file (string_literal) (identifier))
"""
This _should_ have `markdown` injected!
"""
x

module B
# (identifier)
"""
This _should_ have `markdown` injected!
"""
x
end

begin
# (identifier)
"""
This _should_ have `markdown` injected!
"""
x
end

let
# (identifier)
"""
This _should_ have `markdown` injected!
"""
x
end


# (call_expression)
foobar("This should _not_ have `markdown` injected!", x)

# (prefixed_command_literal)
sql```
SELECT * FROM t
```

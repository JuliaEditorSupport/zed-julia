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

# (call_expression)
foobar("This should _not_ have `markdown` injected!", x)

"""
This _should_ have `markdown` injected!
"""
@cxxdereference function f()
end

"""
This _should_ have `markdown` injected!
"""
@kwdef struct A end

# A top level macro call may precede a docstring.
# There was a bug that has been resolved, for the history see:
# https://github.com/JuliaEditorSupport/zed-julia/issues/15
@qmlfunction foobar

"""
This _should_ have `markdown` injected!
"""
struct A end

# We don't highlight single nor triple quoted strings in macro calls:
# Example 1
@info """
This should _not_ have `markdown` injected!
"""

struct A end

# Example 2
@foobar x "This should _not_ have `markdown` injected!"

struct A end

# Example 3
@foobar "Yo" """This should _not_ have `markdown` injected!"""

struct A end

# Special case when using the @doc macro:
@doc "This _should_ have `markdown` injected!" foobar

# Docstrings may be single-quoted:
"This _should_ have `markdown` injected!"
function foobar end

module X
"This _should_ have `markdown` injected!"
foobar
end

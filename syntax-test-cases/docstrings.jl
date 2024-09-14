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

# BUG: As of Sep. 2024, top level macro calls will steal literals!
# The string following this macro call is parsed as an argument to it.
# https://github.com/JuliaEditorSupport/zed-julia/issues/15
@qmlfunction foobar

"""
This _should_ have `markdown` injected!
"""
struct A end
# We highlight it (correctly) by querying for strings in macrocalls
# where a valid target for docstrings immediately follow the macrocall.

# BUT!
# We don't highlight strings in macrocalls if they are the only argument,
# because this setup is quite plausible:
@info """
This should _not_ have `markdown` injected!
"""

struct A end

# We also don't highlight single-quoted strings as docstrings in this setup,
# because docstrings are _usually_ triple-quoted.
# In other words, this is still highlighted correctly:
@foobar x "This should _not_ have `markdown` injected!"

struct A end

# However, this rare setup is currently highlighted INCORRECTLY.
@foobar "Yo" """This should _not_ have `markdown` injected!"""

struct A end

# Only the docstrings stolen by macros have this restriction applied, so
# for example the following still works: (using the @doc macro)
@doc "This _should_ have `markdown` injected!" foobar

# After cleaning up the queries, the single-quote restriction also applies
# to top level docstrings preceding documentable items. The following is
# highlighed INCORRECTLY:
"This _should_ have `markdown` injected!"
function foobar end

# As is this:
module X
"This _should_ have `markdown` injected!"
foobar
end

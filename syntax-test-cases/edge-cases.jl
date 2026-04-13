# Indices
x[begin]
x[begin:2]
x[2:end]
x[1:2]
x[[begin, end]]
begin
    # this is a block, not an index
end

# ------------
# Zed specials
# ------------

# Character literals
# (highlight as @string)
'w'

# String interpolation
# (highlight `$` as @punctuation.special)
"$(sqrt(2))"

# Macro calls
# (highlight `@name` and `@.` as @function.macro)
@info foo
@. foo * bar

# Function calls in pipes
x = var .|> foo |> bar

# Function definitions
# (highlight the function name as @function.definition)
function foo end
function foo(x) 2x end
function Base.foo(x) 2x end

# Long function definitions with return types and where clauses
# (highlight the function name as @function.definition)
# (these should all show in the outline panel)
function foo_plain(x)
    return x + 1
end

function bar_typed(x)::String
    return string(x)
end

function baz_typed(x::Int)::Int
    return x * 2
end

function qux_typed(x::Int, y::Int)::Float64
    return x / y
end

function quux_where(x::T) where T
    return x + 1
end

function corge_both(x::T)::Int where T
    return x * 2
end

# Macro definitions with return types and where clauses
# (highlight the macro name as @function.macro)
# (all should appear in outline)
macro mymacro(ex)
    return esc(ex)
end

macro typed_macro(ex)::Expr
    return esc(ex)
end

# Short function definitions
# (highlight the function name as @function.definition
# and the equal sign as @keyword.function)
foo(x) = 2x
foo(x)::Int = 2x
foo(x::T) where {T<:Number} = 2x
foo(x::T)::Int where {T<:Number} = 2x
Base.foo(x) = 2x
Base.foo(x)::Int = 2x
Base.foo(x::T) where {T<:Number} = 2x
Base.foo(x::T)::Int where {T<:Number} = 2x

# ----------
# Docstrings
# ----------

@doc """
Docstring with `markdown`.
"""
foo10

"""
Docstring with `markdown`.
"""
foo11

"""
Docstring with `markdown`.
"""
foo12, foo13

"""
Docstring with `markdown`.
"""
function foo14 end

"""
Docstring with `markdown`.
"""
function foo15() end

"""
Docstring with `markdown`.
"""
function foo16(x) 2x end

"""
Docstring with `markdown`.
"""
@foobar function foo17() end

"""
Docstring with `markdown`.
"""
function Base.foo18() end

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
# (highlight `$` and the outer parentheses as @punctuation.special)
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

# Types
struct Bar
    a::T
    b::MyModule.T # pass
    c::MyModule.MySubModule.T # pass
    d::MyModule.MySubModule.MySubSubModule.T # pass
    d::MyModule.MySubModule.MySubSubModule.MySubSubSubModule.T # broken
    e::MyModule.MySubModule.T{Int} # pass
    f::MyModule.MySubModule.T{MyModule.Int} # pass
    g::MyModule.MySubModule.T{MyModule.MySubModule.Int} # pass
    h::MyModule.MySubModule.MySubSubModule.T{MyModule.MySubModule.MySubSubModule.Int} # pass
    i::Array{<:MyModule.MySubModule.T} # pass
    j::Array{>:MyModule.MySubModule.T} # pass
    k::Tuple{MyModule.MySubModule.T,MyModule.MySubModule.U} # pass
end

function bar(w::T) end
function bar(x::MyModule.T, y::MyModule.T) nothing end
function bar(y::MyModule.MySubmodule.T) nothing end
function bar(z::MyModule.MySubmodule.T{MyModule.MySubModule.Int}) nothing end
function bar(z::T) where {T<:MyModule.MySubModule.MySubSubModule.U} nothing end
function bar(z::T) where {T>:MyModule.MySubModule.MySubSubModule.U} nothing end

bar(z::MyModule.MySubmodule.T{MyModule.MySubModule.Int}) where {T<:MyModule.MySubModule.MySubSubModule.U} = nothing
Base.bar(z::MyModule.MySubmodule.T{MyModule.MySubModule.Int}) where {T<:MyModule.MySubModule.MySubSubModule.U} = nothing

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

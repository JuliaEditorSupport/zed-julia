# Test file for block recognition and indentation

# 1. Module Indentation & Selection Test
# Try "Select Enclosing Symbol" inside foo() -> then again -> then again.
# You will see it eventually selects the entire MyModule.
module MyModule
using LinearAlgebra

x = 1

function foo(a)
    println("Processing: ", a)
    begin
        # A nested block
        result = a * 2
        return result
    end
end

function bar(b)
    if b > 0
        return sqrt(b)
    else
        return 0
    end
end
end
# 2. Block Recognition Test (Outline / Selection)
# These should now be recognized as selectable symbols in Zed

begin
    a = 1
    b = 2
    c = a + b
end

# x = 10
x = -10
if x > 0
    println("positive")
else
    println("non-positive")
end

for i in 1:10
    println(i)
end

condition = true
i = 0
while condition
    println(i)
    if i > 3
        condition = false
    end
    i += 1
end

let x = 1, y = 2
    print(x + y)
end


try
    result = sqrt(-1)  # Should throw a DomainError
    println("Result: $result")
catch e
    @error "Caught an error" exception = e
finally
    println("Cleanup complete")
end

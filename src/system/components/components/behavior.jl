"""
Accessing behaviors of components.
"""

# return a vector of behaviors of type B associated with component c
function behaviors(c::Component, B)
    v = B[]
    for b in behaviors(c)
        if b isa B
            push!(v,b)
        end
    end
    return v
end

# return a unique behavior of type B associated with component c
function uniquebehavior(c::Component, B)
    for b in behaviors(c)
        if b isa B
            return b
        end
    end
    return nothing
end

# return true if the component c has a behavior of type B, false otherwise
function hasbehavior(c::Component, B)
    for b in behaviors(c)
        if b isa B
            return true
        end
    end
    return false
end

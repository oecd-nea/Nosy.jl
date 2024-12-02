"""
Tools for behaviors.
"""

# return behaviors of type B
function getbehaviors(c::Component, B)
    v = B[]
    for b in behaviors(c)
        if b isa B
            push!(v, b)
        end
    end
    return v
end

# return a capacity behavior associated with port named pname
function getcapacitybehavior(c::Component, pname::String)
    for b in getbehaviors(c, AbstractCapacityBehavior)
        if _portname(b) == pname
            return b
        end
    end
    throw(AssertionError("No capacity associated with port $pname was found in component $(name(c))"))
end

# return the capacity behavior of c associated with port pname, after checking the modifier is the same as requested
function getcapacitybehavior(c::Component, pname::String, modifier::Function)
    b = getcapacitybehavior(c, pname)
    @assert _modifier(b) == modifier "Modifiers are not compatible ($modifier / $(_modifier(b)))"
    return b
end
"""
Component metrics.
"""

"""
    capacity(c::Component)
Return the capacity of a Component `c`.
If the component has no capacity, return nothing.
"""
function capacity(c::Component)
    cap = uniquebehavior(c, AbstractCapacityBehavior)
    if isnothing(cap) 
        return nothing
    else
        return _capacity(cap)
    end
end
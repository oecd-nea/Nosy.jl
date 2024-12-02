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

"""
    overnightcost(c::Component)
Return the overnight cost of Component `c`.
"""
function overnightcost(c::Component{T})::T where T
    _cost = uniquebehavior(c, OvernightCostBehavior)
    if isnothing(_cost)
        return zero(T)
    else
        return _overnightcost(_cost)
    end
end
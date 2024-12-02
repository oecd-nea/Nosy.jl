"""
Component metrics.
"""

# barrier function to lower allocations as behavior concrete type is not known
# reduces @btime from 450 ns to ~140 ns on Julia 1.11.1 / i7 1365U
_capacity(::Nothing, T::DataType) = 0. # type inference fail still less expensive than AffExpr(0.)
_capacity(c::AbstractCapacityBehavior, ::DataType) = _capacity(c)

"""
    capacity(c::Component)
Return the capacity of a Component `c`.
If the component has no capacity, return zero.
"""
function capacity(c::Component{T}) where T
    return _capacity(uniquebehavior(c, AbstractCapacityBehavior), T)
end


_overnightcost(::Nothing) = 0. # type inference fail still less expensive than AffExpr(0.)

"""
    overnightcost(c::Component)
Return the overnight cost of Component `c`.
If the component has no overnight cost, return zero.
"""
function overnightcost(c::Component)
    return _overnightcost(uniquebehavior(c, OvernightCostBehavior))
end
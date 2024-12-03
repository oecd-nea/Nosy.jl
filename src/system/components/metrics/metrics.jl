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
    return _capacity(uniquebehavior(c, AbstractCapacityBehavior{T}), T)
end

# perform the sum of the metric over the component
# bs is the list of candidate behaviors compatible with the metric
function sumofmetric(c::Component{T}, B, metric) where T
    bs = behaviors(c, B)
    if isempty(bs)
        return 0. # not type-stable, but prevents allocation of AffExpr(0.) each time a component has not the behavior, which is most of the time
    else
        return sum(metric(b)::T for b in bs)
    end
end

"""
    overnightcost(c::Component)
Return the overnight cost of Component `c` as the sum of its overnight costs.
If the component has no overnight cost, return zero.
"""
overnightcost(c::Component{T}) where T = sumofmetric(c, OvernightCostBehavior{T}, _overnightcost)

"""
    variablecost(c::Component)
Return the variable cost of Component `c` as the sum of its variable costs.
If the component has no variable cost, return zero.
"""
variablecost(c::Component{T}) where T = sumofmetric(c, VariableCostBehavior{T}, _variablecost)
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

"""
  nbunits(c::Component)
Return the number of units of Component `c`, related to its capacity and unit size.
If `c` has no capacity or no unit size, return nothing.
"""
function nbunits(c::Component) 
    _cap = uniquebehavior(c, AbstractCapacityBehavior)
    if isnothing(_cap)
        return nothing
    else
        return _nbunits(_cap)
    end
end
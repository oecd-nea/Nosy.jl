"""
Component metrics.
"""

# barrier function to lower allocations as behavior concrete type is not known
# reduces @btime from 450 ns to ~140 ns on Julia 1.11.1 / i7 1365U
_capacity(::Nothing, T::DataType) = 0. # type inference fail still less expensive than GenericAffExpr(0.)
_capacity(c::AbstractCapacityBehavior, ::DataType) = _capacity(c)


"""
    capacity(c::Component)
Return the capacity of a Component `c`.
If `multiplier` is true, return the capacity multiplied with the matching capacity multiplier (same port) if it exists.
If the component has no capacity, return zero.
"""
function capacity(c::Component{T}; multiplier::Bool=false) where T
    cap = uniquebehavior(c, AbstractCapacityBehavior{T})
    local m = 1.
    if multiplier
        vm = getbehaviors(c, CapacityMultiplierBehavior{T})
        for mult in vm
            if _portname(mult) == _portname(cap)
                m = _mult(mult)
                break
            end
        end
    end
    return m * _capacity(cap, T)
end

"""
    capacity(c::Component, pname::String; multiplier::Bool=true)
Return the capacity associated with port named `pname` of component `c`.
If `multiplier` is true, return the capacity multiplied with the matching capacity multiplier (same port) if it exists.
If the component has no port named `pname`, throw an error.
If the component has no capacity associated with port `pname`, return zero.
"""
function capacity(c::Component{T}, pname::String; multiplier::Bool=false) where T
    @assert hasport(c.s, pname) "Component $(name(c)) has no port named $pname"
    cap = getcapacitybehavior(c, pname)
    local m = 1.
    if multiplier
        # look for a capacity multiplier
        vm = getbehaviors(c, CapacityMultiplierBehavior{T})
        for mult in vm
            if _portname(mult) == pname
                m = _mult(mult)
                break
            end
        end
    end
    return m * _capacity(cap)
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
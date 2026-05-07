"""
Component metrics.
"""

# barrier function to lower allocations as behavior concrete type is not known
# reduces @btime from 450 ns to ~140 ns on Julia 1.11.1 / i7 1365U
_capacity(::Nothing, T::DataType) = 0. # type inference fail still less expensive than GenericAffExpr(0.)
_capacity(c::AbstractCapacityBehavior, ::DataType) = _capacity(c)

function _matchingmultipliers(c::Component{T}, cap::AbstractCapacityBehavior{T}) where T
    vm = CapacityMultiplierBehavior{T}[]
    _capport = _portname(cap)
    for mult in getbehaviors(c, CapacityMultiplierBehavior{T})
        if _capport isa String
            if _portname(mult) == _capport
                push!(vm, mult)
            end
        elseif _capport isa AbstractVector{<:AbstractString}
            if _portname(mult) in _capport
                push!(vm, mult)
            end
        end
    end
    return vm
end


"""
    capacity(c::Component; multiplier::Bool=false)

Return the capacity of a Component `c`.
If `multiplier` is true, return the capacity multiplied with the matching capacity multiplier (same port) if it exists.
If the component has no capacity, return zero.
"""
function capacity(c::Component{T}; multiplier::Bool=false) where T
    cap = uniquebehavior(c, AbstractCapacityBehavior{T})
    isnothing(cap) && return _capacity(cap, T)
    local m = 1.
    if multiplier
        vm = _matchingmultipliers(c, cap)
        if length(vm) > 1
            throw(AssertionError("Multiple CapacityMultiplier behaviors match the selected capacity behavior of component $(name(c))."))
        elseif length(vm) == 1
            m = _mult(first(vm))
        end
    end
    return m * _capacity(cap, T)
end

"""
    capacity(c::Component, pname::String; multiplier::Bool=false)

Return the capacity associated with port named `pname` of component `c`.
If `multiplier` is true, return the capacity multiplied with the matching capacity multiplier (same port) if it exists.
If the component has no port named `pname`, throw an error.
If the component has no capacity associated with port `pname`, return `Inf64`.
"""
function capacity(c::Component{T}, pname::String; multiplier::Bool=false) where T
    if !hasport(c, pname)
        throw(AssertionError("Component $(name(c)) has no port named $pname"))
    end
    if hascapacitybehavior(c, pname)
        cap = getcapacitybehavior(c, pname)
    elseif hasbehavior(c, DurationBehavior) # special case: if component (from storage model) has duration, then capacity for pname is evaluated on the fly
        d = first(getbehaviors(c, DurationBehavior))
        cappname = _capacitypname(d)
        cap = getcapacitybehavior(c, cappname)
        if pname in ("input", "output") && cappname in ("input", "output")
            nothing # proceed to evaluate multiplier
        elseif pname == "level"
            return _capacity(cap) * _hours(d) # not managing multiplier for level
        elseif cappname == "level"
            return _capacity(cap) / _hours(d) # not managing multiplier for level
        end
    else
        @warn "No capacity for component " * name(c) * "(port name: " * pname * ")"
        return Inf64
    end
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

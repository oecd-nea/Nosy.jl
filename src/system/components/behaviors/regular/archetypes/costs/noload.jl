"""
No-load cost behavior.
No-load cost requires unit commitment.
"""

struct NoLoadCost <: AbstractCostBehaviorData
    type::Symbol
    pname::String
    val::Float64

    @doc """
        NoLoadCost(type::Symbol, pname::String, val::Number)

    Return `NoLoadCost` behavior data associated with cost type `type`, port name `pname`, and hourly cost `val`.
    """
    function NoLoadCost(type::Symbol, pname::String, val::Number) 
        return new(type, pname, Float64(val))
    end
end


struct NoLoadCostBehavior{T<:VAL} <: AbstractCostBehavior{T}
    data::NoLoadCost
    val::T
end

function buildbehavior(c::Component{T}, b::NoLoadCost) where T
    vuc = getbehaviors(c, Nosy.AbstractFleetUnitCommitmentBehavior{T}) # TODO update when other unit commitment behaviors are implemented
    local uc = nothing
    for _uc in vuc
        portname(_uc) == b.pname ? uc = _uc : nothing
        break
    end
    if isnothing(uc) 
        throw(AssertionError("Component $(name(c)) does not have a unit commitment behavior for port $(b.pname)"))
    end
    # NB `_up(uc)` counts committed units: it is a step function, not a quantity varying
    # linearly between instants, so it must not be integrated with the trapezoid rule
    # used by `sum(::Stepwise)`. `_interval_sum` weights each step by its own duration.
    _cost = _interval_sum(_up(uc)) * b.val
    return NoLoadCostBehavior(b, _cost)
end

# no constraint associated with cost

_costtype(b::NoLoadCostBehavior) = b.data.type

_noloadcost(b::NoLoadCostBehavior) = b.val # value is calculated and stored

_portname(b::NoLoadCostBehavior) = b.data.pname

behaviorname(::NoLoadCostBehavior) = "no-load cost"

_apply_constraints!(::Component, ::NoLoadCostBehavior) = nothing
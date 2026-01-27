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
    Return an NoLoadCost behavior data, associated with port name `pname` and hourly cost `val`.
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
    _cost = sum(_up(uc)) * b.val # NB step weights already included in the sum(_up(uc)) as _up(uc) is a Stepwise series
    return NoLoadCostBehavior(b, _cost)
end

# no constraint associated with cost

_costtype(b::NoLoadCostBehavior) = b.data.type

_noloadcost(b::NoLoadCostBehavior) = b.val # value is calculated and stored

_portname(b::NoLoadCostBehavior) = b.data.pname

behaviorname(::NoLoadCostBehavior) = "no-load cost"

_apply_constraints!(::Component, ::NoLoadCostBehavior) = nothing
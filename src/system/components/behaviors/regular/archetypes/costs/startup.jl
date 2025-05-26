"""
Startup cost behavior.
Startup cost requires unit commitment.
"""

struct StartupCost <: AbstractCostBehaviorData
    type::Symbol
    pname::String
    val::Number

    @doc """
        StartupCost(type::Symbol, pname::String, val::Number)
    Return an StartupCost behavior data, associated with port name `pname` and per-startup cost `val`.
    """
    function StartupCost(type::Symbol, pname::String, val::Number) 
        return new(type, pname, Float64(val))
    end
end


struct StartupCostBehavior{T<:VAL} <: AbstractCostBehavior{T}
    data::StartupCost
    val::T
end

function buildbehavior(c::Component{T}, b::StartupCost) where T
    vuc = getbehaviors(c, AbstractFleetUnitCommitmentBehavior{T}) # TODO update when other unit commitment behaviors are implemented
    local uc = nothing
    for _uc in vuc
        portname(_uc) == b.pname ? uc = _uc : nothing
        break
    end
    @assert !isnothing(uc) "Component $(name(c)) does not have a unit commitment behavior for port $(b.pname)"
    _cost = sum(uc.startup.data) * b.val # we need to sum the switch states, so they must not be weighted
    return StartupCostBehavior{T}(b, convert(T,_cost))
end

# no constraint associated with cost

_costtype(b::StartupCostBehavior) = b.data.type

_startupcost(b::StartupCostBehavior) = b.val # value is calculated and stored

_portname(b::StartupCostBehavior) = b.data.pname

behaviorname(::StartupCostBehavior) = "startup cost"

_apply_constraints!(::Component, ::StartupCostBehavior) = nothing
using JuMP: @variable, AffExpr
using ArgCheck: @argcheck

"""
Behavior: fixed capacity.
"""

struct FixedCapacity{M<:Function} <: AbstractCapacityData
    pname::String
    modifier::M
    val::Float64

    @doc """
        FixedCapacity(pname::String, modifier::Function, val::Number)
    Return a FixedCapacity behavior data, associated with port name `pname`, modifier `modifier` and fixed value `val`.
    """
    function FixedCapacity(pname::String, modifier::Function, val::Number)        
        @argcheck val >= 0. "Capacity cannot be negative"
        new{typeof(modifier)}(pname, modifier, Float64(val))
    end
end

struct FixedCapacityBehavior{T<:VAL,M<:Function} <: AbstractCapacityBehavior{T}
    data::FixedCapacity{M}
    val::T
end


# return a FixedCapacityBehavior
# NB string is not used as no variable is created
function buildbehavior(m::AbstractModel, ::String, b::FixedCapacity{M}) where M
    @argcheck hasport(m, b.pname) "Model does not have port named $(b.pname)"
    @argcheck hasmodifier(getport(m, b.pname), b.modifier) "Target port does not have the required modifier"
    return FixedCapacityBehavior(b, AffExpr(b.val))
end

# general case: apply constraint at each timestep
function _apply_constraints!(m::AbstractModel, b::FixedCapacityBehavior)
    @constraint(sim(m).model, b.data.modifier(getport(m, b.data.pname)).data .<= _capacity(b))
end

# special case - ProfileSourceModel: apply constraint at each timestep
function _apply_constraints!(m::ProfileSourceModel, b::FixedCapacityBehavior)
    @argcheck b.data.modifier == _defaultmodifier(carrierstyle(m.data.carrier)) "no modifier conversion allowed between component and capacity"
    @constraint(sim(m).model, m.cap == b.val)
end

# redirect application of capacity constraint to model
# NB capacity is not applied to joint flows with this workflow
function _apply_constraints!(c::Component, b::FixedCapacityBehavior)
    _apply_constraints!(model(c), b)
end

behaviorname(::FixedCapacityBehavior) = "fixed capacity"

# return the AffExpr
_capacity(c::FixedCapacityBehavior) = c.val

_portname(c::FixedCapacityBehavior) = c.data.pname
_modifier(c::FixedCapacityBehavior) = c.data.modifier
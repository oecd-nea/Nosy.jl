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
end


# Default constructor for parameter = Number type.
# Used when building T=Float64 version of the system after value extraction.
FixedCapacityBehavior(data::FixedCapacity{M}) where M = FixedCapacityBehavior{Float64,M}(data)

# return a FixedCapacityBehavior
# NB string is not used as no variable is created
function buildbehavior(m::AbstractModel, ::String, b::FixedCapacity{M}) where M
    @argcheck hasport(m, b.pname) "Model does not have port named $(b.pname)"
    @argcheck hasmodifier(getport(m, b.pname), b.modifier) "Target port does not have the required modifier"
    return FixedCapacityBehavior{AffExpr,M}(b)
end

# apply the component constraints related to fixed capacity
function _apply_constraints!(c::Component, b::FixedCapacityBehavior)
    @constraint(sim(c).model, b.data.modifier(getport(model(c), b.data.pname)) .<= _capacity(b))
end

behaviorname(::FixedCapacityBehavior) = "fixed capacity"

# return the AffExpr
_capacity(c::FixedCapacityBehavior) = c.data.val

_portname(c::FixedCapacityBehavior) = c.data.pname
_modifier(c::FixedCapacityBehavior) = c.data.modifier
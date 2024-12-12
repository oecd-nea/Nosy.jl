using JuMP: @variable, AffExpr
using ArgCheck: @argcheck

"""
Behavior: variable capacity.
"""

struct VariableCapacity{M<:Function} <: AbstractCapacityData
    pname::String
    modifier::M
    lb::Float64
    ub::Float64

    @doc """
        VariableCapacity(pname::String, modifier::Function; lb=0., ub=Inf)
    Return a VariableCapacity behavior data, associated with port name `pname` and modifier `modifier`.
    Optional parameters:
      * lb: lower bound
      * ub: upper bound
    """
    function VariableCapacity(pname::String, modifier::Function; lb::Number=0., ub::Number=Inf)        
        @argcheck lb >= 0. "Capacity cannot be negative"
        @argcheck lb <= ub "Lower bound is bigger than upper bound"
        new{typeof(modifier)}(pname, modifier, Float64(lb), Float64(ub))
    end
end

struct VariableCapacityBehavior{T<:VAL,M<:Function} <: AbstractCapacityBehavior{T}
    data::VariableCapacity{M}
    val::T
end

# return a VariableCapacityBehavior
function buildbehavior(m::AbstractModel, cname::String, b::VariableCapacity)
    @argcheck hasport(m, b.pname) "Model does not have port named $(b.pname)"
    @argcheck hasmodifier(getport(m, b.pname), b.modifier) "Target port does not have the required modifier"
    v = @variable(sim(m).model, base_name=cname * "_" * b.pname * "_" * modifiername(b.modifier) * "_" * "cap", lower_bound=b.lb, upper_bound=b.ub, integer=false, binary=false)
    return VariableCapacityBehavior(b, convert(AffExpr, v))
end

# special case - DemandModel: not compatible (already has an implicit capacity as the demand series is not normalized)
function buildbehavior(::DemandModel, ::String, ::VariableCapacity)
    throw(ArgumentError("Demand model is not compatible with capacity"))
end

# general case: apply constraint at each timestep
function _apply_constraints!(m::AbstractModel, b::VariableCapacityBehavior)
    @constraint(sim(m).model, b.data.modifier(getport(m, b.data.pname)).data .<= _capacity(b))
end

# special case - ProfileSourceModel: apply constraint at each timestep
function _apply_constraints!(m::ProfileSourceModel, b::VariableCapacityBehavior)
    @argcheck b.data.modifier == _defaultmodifier(carrierstyle(carrier(getport(m, b.data.pname)))) "no modifier conversion allowed between component and capacity"
    @constraint(sim(m).model, m.cap == b.val)
end

# special case: any model, but presence of capacity multiplier behavior
function _apply_constraints!(m::AbstractModel, b::VariableCapacityBehavior, mult::CapacityMultiplierBehavior)
    @argcheck b.data.modifier == _defaultmodifier(carrierstyle(carrier(getport(m, b.data.pname)))) "no modifier conversion allowed between component and capacity"
    @argcheck _portname(b) == _portname(mult) "the variable capacity and the capacity multiplier do not target the same port"
    @constraint(sim(m).model, b.data.modifier(getport(m, b.data.pname)).data .<= (_capacity(b) * mult.val).data)
end

# redirect application of capacity constraint to model
# NB capacity is not applied to joint flows with this workflow
function _apply_constraints!(c::Component, b::VariableCapacityBehavior)
    local hasmatchingmultiplierbehavior = false
    if hasbehavior(c, CapacityMultiplierBehavior)
        for mult in getbehaviors(c, CapacityMultiplierBehavior)
            if _portname(mult) == _portname(b)
                hasmatchingmultiplierbehavior = true
                _apply_constraints!(model(c), b, mult)
                break
            end
        end
    end

    if !hasmatchingmultiplierbehavior
        _apply_constraints!(model(c), b)
    end
end

behaviorname(::VariableCapacityBehavior) = "variable capacity"

# return the AffExpr
_capacity(c::VariableCapacityBehavior) = c.val

_portname(c::VariableCapacityBehavior) = c.data.pname
_modifier(c::VariableCapacityBehavior) = c.data.modifier
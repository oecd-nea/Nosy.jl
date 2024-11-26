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

struct VariableCapacityBehavior{M<:Function,T<:VAL} <: AbstractCapacityBehavior{T}
    data::VariableCapacity{M}
    val::T
end

# return a VariableCapacityBehavior
function buildbehavior(m::AbstractModel, b::VariableCapacity)
    @argcheck hasport(m, b.pname) "Model does not have port named $(b.pname)"
    @argcheck hasmodifier(getport(m, b.pname), b.modifier) "Target port does not have the required modifier"
    v = @variable(sim(m).model, lower_bound=b.lb, upper_bound=b.ub, integer=false, binary=false)
    return VariableCapacityBehavior(b, convert(AffExpr, v))
end

# return the AffExpr
_capacity(c::VariableCapacityBehavior) = c.val

# apply the component constraints related to variable capacity
function _apply_constraints!(c::AbstractComponent, b::VariableCapacityBehavior)

end
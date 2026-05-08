"""
Abstract capacity behaviors.
"""

using JuMP: @constraint
using ArgCheck: @argcheck

# abstract type for capacity behavior data
abstract type AbstractCapacityData <: AbstractRegularBehaviorData end

# abstract type for capacity behavior
abstract type AbstractCapacityBehavior{T} <: AbstractRegularBehavior{T} end

# abstract type for single-port capacity behaviors
abstract type AbstractSingleCapacityBehavior{T} <: AbstractCapacityBehavior{T} end

# abstract type for composed (multi-port) capacity behaviors
abstract type AbstractComposedCapacityBehavior{T} <: AbstractCapacityBehavior{T} end


"""
AbstractCapacityBehavior interface:
  * implement _portname(b::AbstractCapacityBehavior) -> return the associated port name(s)
  * implement _modifier(b::AbstractCapacityBehavior) -> return the associated modifier
"""

_weights(b::AbstractComposedCapacityBehavior) = fill(1., length(_portname(b)))

# sum of targeted flows under a composed capacity behavior
function _composedflow(c::Component, b::AbstractComposedCapacityBehavior)
    pnames = _portname(b)
    _mod = _modifier(b)
    weights = _weights(b)
    _f = weights[1] * _mod(getport(c, first(pnames)))
    for (pname, weight) in zip(pnames[2:end], weights[2:end])
        _f += weight * _mod(getport(c, pname))
    end
    return _f
end

# general expression of composed capacity constraint
function __apply_constraint_general!(c::Component, b::AbstractComposedCapacityBehavior)
    @constraint(lowermodel(sim(c)), _composedflow(c, b).data .<= _capacity(b))
end

# return multipliers matching at least one target port of the composed capacity behavior
function _matchingcomposedmultipliers(c::Component, b::AbstractComposedCapacityBehavior)
    vmult = Any[]
    pnames = _portname(b)
    if hasbehavior(c, CapacityMultiplierBehavior)
        for mult in getbehaviors(c, CapacityMultiplierBehavior)
            if _portname(mult) in pnames
                push!(vmult, mult)
            end
        end
    end
    return vmult
end

# apply composed-capacity constraint with a matching capacity multiplier
function _apply_constraints!(c::Component, b::AbstractComposedCapacityBehavior, mult)
    pnames = _portname(b)
    @argcheck _portname(mult) in pnames "the capacity multiplier does not target a port of this composed capacity"
    _mod = _modifier(b)
    for pname in pnames
        @argcheck _mod == _defaultmodifier(carrierstyle(carrier(getport(c, pname)))) "no modifier conversion allowed between component and capacity multiplier with composed capacity"
    end
    @constraint(lowermodel(sim(c)), _composedflow(c, b).data .<= (_capacity(b) * _mult(mult)).data)
end

# redirect application of composed-capacity constraint to model
function _apply_constraints!(c::Component, b::AbstractComposedCapacityBehavior)
    vmult = _matchingcomposedmultipliers(c, b)
    if length(vmult) > 1
        throw(AssertionError("$(behaviorname(b)) is not compatible with multiple CapacityMultiplier behaviors targeting its ports"))
    elseif length(vmult) == 1
        _apply_constraints!(c, b, first(vmult))
    else
        __apply_constraint_general!(c, b)
    end
end

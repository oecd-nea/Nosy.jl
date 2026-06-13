"""
Capacity multiplier.

Introduces a time-dependent ratio that is applied to capacity.

This behavior interacts with capacity behaviors and modifies their constraint.
The modifier is defined by the capacity behavior, not the capacity multiplier behavior.
"""

struct CapacityMultiplier{V} <: AbstractRegularBehaviorData
    pname::String # the modifier is assumed to be the same as capacity associated with port named pname
    val::V
    @doc"""
        CapacityMultiplier(pname::String, val)

    Return `CapacityMultiplier` behavior data associated with port name `pname` and a scalar or vector value `val`.
    The modifier is assumed to be the same as the capacity associated with port named `pname`.
    """
    function CapacityMultiplier(pname::String, val::V) where V
        @argcheck (val isa Number) || (val isa AbstractVector{<:Number}) "`val` must be a Number or a AbstractVector{<:Number}"
        if val isa Number
            @argcheck val >= 0. "`val` must be positive or zero"
        elseif val isa AbstractVector{<:Number}
            @argcheck all(val .>= 0.) "All elements of `val` must be positive or zero"
        end
        return new{V}(pname, val)
    end
end

struct CapacityMultiplierBehavior{T,V} <: AbstractRegularBehavior{T}
    data::CapacityMultiplier{V}
    val::Stepwise{Float64} # conversion to Stepwise would be costly (~2.5 MB for 1 series of 8760 timesteps)
    _type::Type{T} # to not make a specific constructor
end

function buildbehavior(c::Component, b::CapacityMultiplier)
    if (model(c) isa ProfileSourceModel) 
        throw(AssertionError("Profile source model is not compatible with capacity multiplier"))
    end
    s = Stepwise(b.val, mesh(c))
    return CapacityMultiplierBehavior(b, s, exptype(sim(c)))
end

_portname(b::CapacityMultiplierBehavior) = b.data.pname

_mult(b::CapacityMultiplierBehavior) = b.val

# return true if the capacity behavior targets `pname`
function _matchescapacityport(b::AbstractCapacityBehavior, pname::String)
    _pname = _portname(b)
    if _pname isa String
        return _pname == pname
    elseif _pname isa AbstractVector{<:AbstractString}
        return pname in _pname
    else
        return false
    end
end

# Workflow summary for CapacityMultiplier:
# 1) This behavior has no direct constraint of its own. At build/apply time, it only checks that at
#    least one capacity behavior targets `pname` (single-port or composed via `_matchescapacityport`).
#    If none matches, it throws.
# 2) Actual constraint changes are implemented by capacity behaviors:
#    * FixedCapacity / VariableCapacity: when a multiplier matches the same port, their upper bound
#      is replaced by `capacity(..., multiplier=true)`.
#    * FixedComposedCapacity / VariableComposedCapacity: multiplier applies to the composed bound
#      (`sum(targeted flows) <= capacity * multiplier`) when exactly one targeted multiplier exists.
#      If several multipliers target the composed ports, composed capacities throw.
# 3) The `capacity(c; multiplier=true)` metric applies the same matching logic to the selected
#    capacity behavior and throws when several multipliers match that selected capacity.
#
# check whether c has compatible capacity behavior
# enforcing the constraint itself is delegated to the capacity behavior
function _apply_constraints!(c::Component, m::CapacityMultiplierBehavior) # no inherent constraint; but constraints of FixedCapacity and VariableCapacity are modified
    for b in behaviors(c, AbstractCapacityBehavior)
        if _matchescapacityport(b, _portname(m))
            return nothing
        end
    end
    throw(AssertionError("$(name(c)) has no capacity associated with $(_portname(m))"))
end

behaviorname(::CapacityMultiplierBehavior) = "capacity multiplier"

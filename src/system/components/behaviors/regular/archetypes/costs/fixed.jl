"""
Fixed cost behavior.
Fixed cost is associated with a capacity. A component without capacity has no fixed cost.
"""

struct FixedCost{M<:Function} <: AbstractCostBehaviorData
    type::Symbol
    pname::String
    modifier::M
    val::Float64

    @doc """
        FixedCost(type::Symbol, pname::String, modifier::Function, val::Number)
    Return a FixedCost behavior data, associated with port name `pname`, modifier `modifier` and fixed value `val`.
    """
    function FixedCost(type::Symbol, pname::String, modifier::Function, val::Number)
        @argcheck val >= 0. "Fixed cost cannot be negative"
        new{typeof(modifier)}(type, pname, modifier, Float64(val))
    end
end

struct FixedCostBehavior{T<:VAL,M<:Function} <: AbstractCostBehavior{T}
    data::FixedCost{M}
    val::T # (ov cost of behavior data) x (capacity of component)
end

# must not use the fallback function on model: we need the component to get the capacity behavior
function buildbehavior(c::Component, b::FixedCost)
    # get the associated capacity behavior
    cap = getcapacitybehavior(c, b.pname, b.modifier)
    cost = convert(AffExpr, _capacity(cap) * b.val)
    return FixedCostBehavior(b, cost)
end

# no constraint associated with cost

_costtype(b::FixedCostBehavior) = b.data.type

_fixedcost(b::FixedCostBehavior) = b.val

_portname(b::FixedCostBehavior) = b.data.pname
_modifier(b::FixedCostBehavior) = b.data.modifier

behaviorname(::FixedCostBehavior) = "fixed cost"
_apply_constraints!(::Component, ::FixedCostBehavior) = nothing
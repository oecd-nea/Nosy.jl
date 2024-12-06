"""
Overnight cost behavior.
Overnight cost is associated with a capacity. A component without capacity has no overnight cost.
"""

struct OvernightCost{M<:Function} <: AbstractCostBehaviorData
    type::Symbol
    pname::String
    modifier::M
    val::Float64

    @doc """
        OvernightCost(type::Symbol, pname::String, modifier::Function, val::Number)
    Return an OvernightCost behavior data, associated with port name `pname`, modifier `modifier` and fixed value `val`.
    """
    function OvernightCost(type::Symbol, pname::String, modifier::Function, val::Number)
        @argcheck val >= 0. "Overnight cost cannot be negative"
        new{typeof(modifier)}(type, pname, modifier, Float64(val))
    end
end

struct OvernightCostBehavior{T<:VAL,M<:Function} <: AbstractCostBehavior{T}
    data::OvernightCost{M}
    val::T # (ov cost of behavior data) x (capacity of component)
end

# must not use the fallback function on model: we need the component to get the capacity behavior
function buildbehavior(c::Component, b::OvernightCost)
    # get the associated capacity behavior
    cap = getcapacitybehavior(c, b.pname, b.modifier)
    cost = convert(AffExpr, _capacity(cap) * b.val)
    return OvernightCostBehavior(b, cost)
end

# no constraint associated with cost

_costtype(b::OvernightCostBehavior) = b.data.type

_overnightcost(b::OvernightCostBehavior) = b.val

_portname(b::OvernightCostBehavior) = b.data.pname
_modifier(b::OvernightCostBehavior) = b.data.modifier

behaviorname(::OvernightCostBehavior) = "overnight cost"
_apply_constraints!(::Component, ::OvernightCostBehavior) = nothing
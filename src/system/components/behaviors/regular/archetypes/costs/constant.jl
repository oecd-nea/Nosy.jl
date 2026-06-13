"""
Constant cost behavior.
Constant cost is added directly to a component cost.
"""

struct ConstantCost <: AbstractCostBehaviorData
    type::Symbol
    val::Float64

    @doc """
        ConstantCost(type::Symbol, val::Number)

    Return `ConstantCost` behavior data associated with cost type `type` and constant cost value `val`.
    """
    function ConstantCost(type::Symbol, val::Number)
        @argcheck val >= 0. "Constant cost cannot be negative"
        new(type, Float64(val))
    end
end

struct ConstantCostBehavior{T<:VAL} <: AbstractCostBehavior{T}
    data::ConstantCost
    val::T
end

function buildbehavior(c::Component, b::ConstantCost)
    cost = convert(exptype(sim(c)), b.val)
    return ConstantCostBehavior(b, cost)
end

_costtype(b::ConstantCostBehavior) = b.data.type

_constantcost(b::ConstantCostBehavior) = b.val

behaviorname(::ConstantCostBehavior) = "constant cost"
_apply_constraints!(::Component, ::ConstantCostBehavior) = nothing

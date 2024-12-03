"""
Variable cost behavior.
Variable cost is associated with a flow.
"""

struct VariableCost{M<:Function,V} <: AbstractCostBehaviorData
    pname::String
    modifier::M
    val::V # Float64 or Vector{Float64}

    @doc """
        VariableCost(pname::String, modifier::Function, val)
    Return an VariableCost behavior data, associated with port name `pname`, modifier `modifier` and cost `val`.
    `val` must be either a Number or an AbstractVector{<:Number} with length equal to number of steps or hours.
    """
    function VariableCost(pname::String, modifier::Function, val) 
        # NB variable cost can be negative.
        if val isa AbstractVector{<:Number}
            return new{typeof(modifier),Vector{Float64}}(pname, modifier, convert(Vector{Float64}, val))
        elseif val isa Number
            return new{typeof(modifier),Float64}(pname, modifier, convert(Float64, val))
        else
            throw(ArgumentError("`val` must be a Number or a AbstractVector{<:Number}"))
        end
    end
end


struct VariableCostBehavior{T<:VAL,M<:Function} <: AbstractCostBehavior{T}
    data::VariableCost{M}
    val::T
end

# must not use the fallback function on model: we need the component to get the capacity behavior
function buildbehavior(c::Component, b::VariableCost{M,Float64}) where M
    _cost = sum(_balance_one(c.s, b.pname, b.modifier)) * b.val
    return VariableCostBehavior(b, _cost)
end

function buildbehavior(c::Component, b::VariableCost{M,Vector{Float64}}) where M
    @assert (length(b.val) == nsteps(sim(c)) || length(b.val) == nhours(sim(c))) "The length of variable cost vector must be equal to $(nsteps(sim(c))) or $(nhours(sim(c)))"
    # following result is integration of power * cost over time interval
    # we consider that both flow and price vary linearly between steps
    vc = Stepwise(b.val, sim(c).mesh)
    _cost = sum(Stepwise(_balance_one(c.s, b.pname, b.modifier) .* (2/3 * vc + 1/6 * shift(vc, -1) + 1/6 * shift(vc, 1)), sim(c).mesh))
    return VariableCostBehavior(b, _cost)
end


# no constraint associated with cost

_variablecost(b::VariableCostBehavior) = b.val

_portname(b::VariableCostBehavior) = b.data.pname
_modifier(b::VariableCostBehavior) = b.data.modifier

behaviorname(::VariableCostBehavior) = "variable cost"
_apply_constraints!(::Component, ::VariableCostBehavior) = nothing
using ArgCheck: @argcheck

"""
Variable cost behavior.
Variable cost is associated with a flow.
"""

struct VariableCost{M<:Function,V} <: AbstractCostBehaviorData
    type::Symbol
    pname::String
    modifier::M
    val::V # Float64 or Vector{Float64}
    style::Symbol

    @doc """
        VariableCost(type::Symbol, pname::String, modifier::Function, val; style::Symbol=:step)
    Return an VariableCost behavior data, associated with port name `pname`, modifier `modifier` and cost `val`.
    `val` must be either a Number or an AbstractVector{<:Number} with length equal to number of steps or hours.
    If `val` is a vector, then `style` determines how it must be interpreted:
      * if style = `:step`, the cost is assumed to be a step function
      * if style = `:linear`, the cost is assumed to vary linearly between timesteps.
    If `val` is a number, `style` has no effect.
    """
    function VariableCost(type::Symbol, pname::String, modifier::Function, val; style::Symbol=:step) 
        @argcheck style in (:step, :linear) "`style` must be :step or :linear"
        
        # NB variable cost can be negative.
        if val isa AbstractVector{<:Number}
            return new{typeof(modifier),Vector{Float64}}(type, pname, modifier, convert(Vector{Float64}, val), style)
        elseif val isa Number
            return new{typeof(modifier),Float64}(type, pname, modifier, convert(Float64, val), style)
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
    _cost = sum(_balance_one(c.s, b.pname, name(c), b.modifier)) * b.val
    return VariableCostBehavior(b, _cost)
end

function buildbehavior(c::Component, b::VariableCost{M,Vector{Float64}}) where M
    if !(length(b.val) == nsteps(sim(c)) || length(b.val) == nhours(sim(c))) 
        throw(ArgumentError("The length of variable cost vector must be equal to $(nsteps(sim(c))) or $(nhours(sim(c)))"))
    end
    _cost = Stepwise(b.val, sim(c).mesh)
    _flow = _balance_one(c.s, b.pname, name(c), b.modifier)

    # here we assume, as for the rest of the model, that the flow (~power) is linear between steps
    # integration of power * cost over time depends on the shape of cost
    if b.style == :step # integrate power * cost over time assuming cost is a step function
        _cost = sum(Stepwise(_cost .* (1/2 * _flow + 1/2 * shift(_flow, 1)), sim(c).mesh))
    elseif b.style == :linear # integrate power * cost over time assuming cost is a linear function
        _cost = sum(1/3 * (_flow .* _cost) + 1/6 * (_flow .* shift(_cost, 1)) + 1/6 * (shift(_flow, 1) .* _cost) + 1/3 * (shift(_flow, 1) .* shift(_cost, 1))) # NB as there is summation, the formula could be simplified but we leave it this way for clarity
    end

    return VariableCostBehavior(b, _cost)
end


# no constraint associated with cost

_costtype(b::VariableCostBehavior) = b.data.type

_variablecost(b::VariableCostBehavior) = b.val

_portname(b::VariableCostBehavior) = b.data.pname
_modifier(b::VariableCostBehavior) = b.data.modifier

behaviorname(::VariableCostBehavior) = "variable cost"
_apply_constraints!(::Component, ::VariableCostBehavior) = nothing
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

# return true if capacity behavior `cap` targets port name `pname`
function _matchescostcapacityport(cap::AbstractCapacityBehavior, pname::String)
    _pname = _portname(cap)
    if _pname isa String
        return _pname == pname
    elseif _pname isa AbstractVector{<:AbstractString}
        return pname in _pname
    else
        return false
    end
end

# return the unique capacity behavior targeted by fixed cost
function _fixedcostcapacitybehavior(c::Component, b::FixedCost)
    matches = AbstractCapacityBehavior[]
    for cap in getbehaviors(c, AbstractCapacityBehavior)
        if _matchescostcapacityport(cap, b.pname)
            push!(matches, cap)
        end
    end
    isempty(matches) && throw(AssertionError("No capacity associated with port $(b.pname) was found in component $(name(c))"))

    compatible = AbstractCapacityBehavior[]
    for cap in matches
        if _modifier(cap) == b.modifier
            push!(compatible, cap)
        end
    end
    isempty(compatible) && throw(ArgumentError("Modifiers are not compatible ($(_modifier(first(matches))) / $(b.modifier))"))
    if length(compatible) > 1
        throw(AssertionError("Multiple capacities are associated with port $(b.pname) and modifier $(b.modifier). FixedCost is ambiguous."))
    end
    return first(compatible)
end

# must not use the fallback function on model: we need the component to get the capacity behavior
function buildbehavior(c::Component, b::FixedCost)
    # get the associated capacity behavior
    cap = _fixedcostcapacitybehavior(c, b)
    cost = convert(exptype(sim(c)), _capacity(cap) * b.val)
    return FixedCostBehavior(b, cost)
end

# no constraint associated with cost

_costtype(b::FixedCostBehavior) = b.data.type

_fixedcost(b::FixedCostBehavior) = b.val

_portname(b::FixedCostBehavior) = b.data.pname
_modifier(b::FixedCostBehavior) = b.data.modifier

behaviorname(::FixedCostBehavior) = "fixed cost"
_apply_constraints!(::Component, ::FixedCostBehavior) = nothing

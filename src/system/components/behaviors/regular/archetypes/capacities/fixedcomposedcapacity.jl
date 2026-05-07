using JuMP: GenericAffExpr
using ArgCheck: @argcheck

"""
Behavior: fixed composed capacity.

Constrains the sum of several target flows under one fixed capacity value.
"""

struct FixedComposedCapacity{M<:Function} <: AbstractCapacityData
    pname::Vector{String}
    modifier::M
    val::Float64
    unitsize::Union{Nothing,Float64}
end

"""
    FixedComposedCapacity(pname::Union{String,Vector{String}}, modifier::Function, val::Number; unitsize::Union{Nothing,Number})

Return `FixedComposedCapacity` behavior data associated with one or several port names `pname`, modifier `modifier`, and fixed value `val`.
The capacity applies to the sum of targeted flows.
If `unitsize` is a number, it is the size of one unit when considering a fleet.
"""
function FixedComposedCapacity(pname::Union{String,Vector{String}}, modifier::Function, val::Number; unitsize::Union{Nothing,Number}=nothing)
    _pname = pname isa String ? [pname] : copy(pname)
    @argcheck !isempty(_pname) "pname must contain at least one port name"
    @argcheck length(unique(_pname)) == length(_pname) "pname cannot contain duplicates"
    @argcheck val >= 0. "Capacity cannot be negative"
    if unitsize isa Number
        @argcheck unitsize > 0 "unitsize must be strictly positive"
        unitsize = Float64(unitsize)
    end
    FixedComposedCapacity(_pname, modifier, Float64(val), unitsize)
end

struct FixedComposedCapacityBehavior{T<:VAL,M<:Function} <: AbstractComposedCapacityBehavior{T}
    data::FixedComposedCapacity{M}
    val::T
end

# return a FixedComposedCapacityBehavior
function buildbehavior(c::Component, b::FixedComposedCapacity{M}) where M
    @argcheck !(model(c) isa ProfileSourceModel) "Profile source model is not compatible with FixedComposedCapacity"
    for pname in b.pname
        @argcheck hasport(c, pname) "Component does not have port named $pname"
        @argcheck hasmodifier(getport(c, pname), b.modifier) "Target port $pname does not have the required modifier"
    end
    return FixedComposedCapacityBehavior(b, _to_affexpr(b.val, sim(c).model))
end

behaviorname(::FixedComposedCapacityBehavior) = "fixed composed capacity"

# return a Number
_capacity(c::FixedComposedCapacityBehavior{<:GenericAffExpr}) = c.val.constant
_capacity(c::FixedComposedCapacityBehavior{Float64}) = c.val

_portname(c::FixedComposedCapacityBehavior) = c.data.pname
_modifier(c::FixedComposedCapacityBehavior) = c.data.modifier

_unitsize(c::FixedComposedCapacityBehavior) = c.data.unitsize

# evaluate the number of units of the behavior
# return nothing if the unitsize is not defined
function _nbunits(c::FixedComposedCapacityBehavior)
    if isnothing(c.data.unitsize)
        return nothing
    else
        return _capacity(c) / _unitsize(c)
    end
end

# return the maximum number of units
# for FixedComposedCapacityBehavior, it is the number of units
_nbunitsmax(c::FixedComposedCapacityBehavior) = _nbunits(c)

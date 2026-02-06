using JuMP: @variable, GenericAffExpr
using ArgCheck: @argcheck

"""
Behavior: fixed capacity.
"""

struct FixedCapacity{M<:Function} <: AbstractCapacityData
    pname::String
    modifier::M
    val::Float64
    unitsize::Union{Nothing,Float64}
end

"""
    FixedCapacity(pname::String, modifier::Function, val::Number; unitsize::Union{Nothing,Number})
Return a FixedCapacity behavior data, associated with port name `pname`, modifier `modifier` and fixed value `val`.
If unitsize is a number: it is the size of the unit when considering a fleet
"""
function FixedCapacity(pname::String, modifier::Function, val::Number; unitsize::Union{Nothing,Number}=nothing)
    @argcheck val >= 0. "Capacity cannot be negative"
    if unitsize isa Number 
        @argcheck unitsize > 0 "unitsize must be strictly positive"
        unitsize = Float64(unitsize)
    end
    FixedCapacity(pname, modifier, Float64(val), unitsize)
end

struct FixedCapacityBehavior{T<:VAL,M<:Function} <: AbstractSingleCapacityBehavior{T}
    data::FixedCapacity{M}
    val::T
end

# return a FixedCapacityBehavior
# NB string is not used as no variable is created
function buildbehavior(c::Component, b::FixedCapacity{M}) where M
    @argcheck hasport(c, b.pname) "Component does not have port named $(b.pname)"
    @argcheck hasmodifier(getport(c, b.pname), b.modifier) "Target port does not have the required modifier"
    return FixedCapacityBehavior(b, _to_affexpr(b.val, sim(c).model))
end


# for ProfileSource, we need to "apply" the behavior here
# the reason is that this behavior must be enforce before the call to other behaviors
# in particular: before call to VariableCost, which requires the flow being defined
function _addbehavior!(c::Component, b::FixedCapacityBehavior, m::ProfileSourceModel)
    @argcheck b.data.modifier == _defaultmodifier(carrierstyle(carrier(getport(c, _portname(b))))) "no modifier conversion allowed between component and capacity"
    c.model.s.output[PortRef(name(c), "output")].series .= _to_affexpr.(_capacity(b) * _profile(m), sim(c).model)
    push!(c.behaviors, b)
end


"""
Apply capacity constraints.
"""

# general expression of capacity constraint
# can target model port or joint flow port
function __apply_constraint_general!(c::Component, b::FixedCapacityBehavior)
    flow = b.data.modifier(getport(c, b.data.pname)).data
    cap = _capacity(b)

    lm = lowermodel(sim(c)) # type unstable, don't access it in loop

    for s in eachindex(flow)
        if _is_equivalent_to_variable(flow[s])
            set_upper_bound(flow[s], cap)
        else
            @constraint(lm, flow[s] <= cap)
        end
    end
end

# special case - ProfileSourceModel: behavior is enforced throuhg _addbehavior!
function __apply_constraints_profile!(::Component, ::FixedCapacityBehavior) end

# general case: apply constraint at each timestep
# dispatch to either general case or model = profile source case
function __apply_constraints!(c::Component, b::FixedCapacityBehavior)
    if model(c) isa ProfileSourceModel && _portname(b) == "output"
        __apply_constraints_profile!(c, b)
    else
        __apply_constraint_general!(c, b)
    end
end


# special case: any model, but presence of capacity multiplier behavior
function _apply_constraints!(c::Component, b::FixedCapacityBehavior, mult::CapacityMultiplierBehavior)
    @argcheck b.data.modifier == _defaultmodifier(carrierstyle(carrier(getport(c, b.data.pname)))) "no modifier conversion allowed between component and capacity"
    @argcheck _portname(b) == _portname(mult) "the fixed capacity and the capacity multiplier do not target the same port"

    flow = b.data.modifier(getport(c, b.data.pname)).data
    cap = capacity(c, _portname(b), multiplier=true).data

    lm = lowermodel(sim(c)) # type unstable, don't access it in loop

    for s in eachindex(flow)
        if _is_equivalent_to_variable(flow[s])
            set_upper_bound(flow[s], cap[s])
        else
            @constraint(lm, flow[s] <= cap[s])
        end
    end
end

# redirect application of capacity constraint to model
# NB capacity is not applied to joint flows with this workflow
# also checks whether component has CapacityMultiplier behavior
# which does impact the _apply_constraints! method it is dispatched to
function _apply_constraints!(c::Component, b::FixedCapacityBehavior)
    local hasmatchingmultiplierbehavior = false
    if hasbehavior(c, CapacityMultiplierBehavior)
        for mult in getbehaviors(c, CapacityMultiplierBehavior)
            if _portname(mult) == _portname(b)
                hasmatchingmultiplierbehavior = true
                _apply_constraints!(c, b, mult)
                break
            end
        end
    end

    if !hasmatchingmultiplierbehavior
        __apply_constraints!(c, b) # 2 underscores
    end
end

behaviorname(::FixedCapacityBehavior) = "fixed capacity"

# return a Number
_capacity(c::FixedCapacityBehavior{<:GenericAffExpr}) = c.val.constant
_capacity(c::FixedCapacityBehavior{Float64}) = c.val

_portname(c::FixedCapacityBehavior) = c.data.pname
_modifier(c::FixedCapacityBehavior) = c.data.modifier

_unitsize(c::FixedCapacityBehavior) = c.data.unitsize

# evaluate the number of units of the behavior
# return nothing if the unitsize is not defined
function _nbunits(c::FixedCapacityBehavior)
    if isnothing(c.data.unitsize)
        return nothing
    else
        return _capacity(c) / _unitsize(c)
    end
end

# return the maximum number of units
# for FixedCapacityBehavior, it is the number of units
_nbunitsmax(c::FixedCapacityBehavior) = _nbunits(c)

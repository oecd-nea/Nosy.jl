using JuMP: @variable, GenericAffExpr, set_upper_bound, set_lower_bound
using ArgCheck: @argcheck

"""
Behavior: variable capacity.
"""

struct VariableCapacity{M<:Function} <: AbstractCapacityData
    pname::String
    modifier::M
    lb::Float64
    ub::Float64
    unitsize::Union{Nothing,Float64}
    integer::Bool
end

"""
    VariableCapacity(pname::String, modifier::Function; lb::Number=0., ub::Number=Inf, unitsize::Union{Nothing,Number}, integer::Bool)
Return a VariableCapacity behavior data, associated with port name `pname` and modifier `modifier`.
Optional parameters:
* lb: lower bound
* ub: upper bound
* unitsize: size of the unit when considering a fleet
* integer: if unitsize is a number, constrains the number of units to be integer
"""
function VariableCapacity(pname::String, modifier::Function; lb::Number=0., ub::Number=Inf, unitsize::Union{Nothing,Number}=nothing, integer::Bool=false)
    @argcheck lb >= 0. "Capacity cannot be negative"
    @argcheck lb <= ub "Lower bound is bigger than upper bound"
    @argcheck !integer || !isnothing(size) "unitsize must be a Number in order to activate integer number of units"
    unitsize isa Number ? unitsize = Float64(unitsize) : nothing
    VariableCapacity(pname, modifier, Float64(lb), Float64(ub), unitsize, integer)
end

struct VariableCapacityBehavior{T<:VAL,M<:Function} <: AbstractCapacityBehavior{T}
    data::VariableCapacity{M}
    val::T
end

# return a VariableCapacityBehavior
function buildbehavior(c::Component, b::VariableCapacity)
    # _check_model_compat_cap(model(c), b)
    @argcheck hasport(c, b.pname) "Component does not have port named $(b.pname)"
    @argcheck hasmodifier(getport(c, b.pname), b.modifier) "Target port does not have the required modifier"
    if b.unitsize isa Number
        # variable is number of units
        v = @variable(lowermodel(sim(c)), base_name=name(c) * "_" * b.pname * "_" * modifiername(b.modifier) * "_" * "units", lower_bound=b.lb / b.unitsize, upper_bound=b.ub / b.unitsize, integer=b.integer, binary=false)
        e = v * b.unitsize
    else
        # variable is capacity
        v = @variable(lowermodel(sim(c)), base_name=name(c) * "_" * b.pname * "_" * modifiername(b.modifier) * "_" * "cap", lower_bound=b.lb, upper_bound=b.ub, integer=false, binary=false)
        e = _to_affexpr(v, sim(c).model)
    end
    return VariableCapacityBehavior(b, e)
end

# for ProfileSource, we need to "apply" the behavior here
# the reason is that this behavior must be enforce before the call to other behaviors
# in particular: before call to VariableCost, which requires the flow being defined
function _addbehavior!(c::Component, b::VariableCapacityBehavior, m::ProfileSourceModel)
    @argcheck b.data.modifier == _defaultmodifier(carrierstyle(carrier(getport(c, _portname(b))))) "no modifier conversion allowed between component and capacity"
    balance(c, :output, defaultmodifier, collapse=false, aggregate=false)["output"] .= _capacity(b) * _profile(m)
    #_output(m.s)["output"].series .= _capacity(b) * _profile(m)
    push!(c.behaviors, b)
end

"""
Apply capacity constraints.
"""

# general expression of capacity constraint
# can target model port or joint flow port
function __apply_constraint_general!(c::Component, b::VariableCapacityBehavior)
    @constraint(lowermodel(sim(c)), b.data.modifier(getport(c, b.data.pname)).data .<= _capacity(b))

    # set upper bounds for the flow
    # makes the problem more tight (possibly better for MIP) but makes the matrix less sparse (possibly worse for LP)
    # _cap = _capacity(b)
    # if (length(_cap.terms) == 1) && iszero(_cap.constant)
    #     if has_upper_bound(first(_cap.terms)[1])
    #         _ubcap = upper_bound(first(_cap.terms)[1]) * first(_cap.terms)[2]
    #         vf = b.data.modifier(getport(c, b.data.pname)).data
    #         # check first element, assume others are built the same way
    #         if iszero(first(vf).constant) && length(first(vf).terms) == 1
    #             for e in vf
    #                 var = first(e.terms)[1]
    #                 ub = _ubcap / first(e.terms)[2]
    #                 if (!has_upper_bound(var)) || upper_bound(var) > ub 
    #                     set_upper_bound(var, ub, force=true)
    #                 end
    #             end
    #         end
    #     end
    # end

end

# special case - ProfileSourceModel: behavior is enforced throuhg _addbehavior!
function __apply_constraints_profile!(::Component, ::VariableCapacityBehavior) end

# general case: apply constraint at each timestep
# dispatch to either general case or model = profile source case
function __apply_constraints!(c::Component, b::VariableCapacityBehavior)
    if model(c) isa ProfileSourceModel && _portname(b) == "output"
        __apply_constraints_profile!(c, b)
    else
        __apply_constraint_general!(c, b)
    end
end

# special case: any model, but presence of capacity multiplier behavior
function _apply_constraints!(c::Component, b::VariableCapacityBehavior, mult::CapacityMultiplierBehavior)
    @argcheck b.data.modifier == _defaultmodifier(carrierstyle(carrier(getport(c, b.data.pname)))) "no modifier conversion allowed between component and capacity"
    @argcheck _portname(b) == _portname(mult) "the variable capacity and the capacity multiplier do not target the same port"
    @constraint(lowermodel(sim(c)), b.data.modifier(getport(c, b.data.pname)).data .<= capacity(c, _portname(b), multiplier=true).data)
end

# redirect application of capacity constraint to model
# NB capacity is not applied to joint flows with this workflow
function _apply_constraints!(c::Component, b::VariableCapacityBehavior)
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
        __apply_constraints!(c, b)
    end
end

behaviorname(::VariableCapacityBehavior) = "variable capacity"

# return the GenericAffExpr
_capacity(c::VariableCapacityBehavior) = c.val

_portname(c::VariableCapacityBehavior) = c.data.pname
_modifier(c::VariableCapacityBehavior) = c.data.modifier

_unitsize(c::VariableCapacityBehavior) = c.data.unitsize

# evaluate the number of units of the behavior
# return nothing if the unitsize is not defined
function _nbunits(c::VariableCapacityBehavior)
    if isnothing(c.data.unitsize)
        return nothing
    else
        return _capacity(c) / _unitsize(c)
    end
end

# return the maximum number of units
_nbunitsmax(c::VariableCapacityBehavior) = c.data.ub / _unitsize(c)
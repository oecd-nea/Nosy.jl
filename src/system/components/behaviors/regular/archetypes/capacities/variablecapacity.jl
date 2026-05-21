using JuMP: @variable, @constraint, GenericAffExpr, GenericVariableRef, set_integer, set_upper_bound, set_lower_bound, set_start_value
using ArgCheck: @argcheck

"""
Behavior: variable capacity.
"""

struct VariableCapacity{M<:Function,E<:Union{Nothing,GenericVariableRef,GenericAffExpr}} <: AbstractCapacityData
    pname::String
    modifier::M
    lb::Float64
    ub::Float64
    warmstart::Union{Nothing,Float64}
    unitsize::Union{Nothing,Float64}
    integer::Bool
    expr::E
end

"""
    VariableCapacity(pname::String, modifier::Function; lb::Number=0., ub::Number=Inf, warmstart::Union{Nothing,Number}=nothing, unitsize::Union{Nothing,Number}=nothing, integer::Bool=false, expression::Union{Nothing,GenericVariableRef,GenericAffExpr,Number}=nothing)

Return `VariableCapacity` behavior data associated with port name `pname` and modifier `modifier`.
Optional parameters:
  * `lb`: lower bound
  * `ub`: upper bound
  * `warmstart`: initial value for the capacity variable
  * `unitsize`: size of one unit when considering a fleet
  * `integer`: if `unitsize` is a number, constrain the number of units to be integer
  * `expression`: reused capacity input (`nothing`, `GenericVariableRef`, `GenericAffExpr`, or `Number`)

A numeric `expression` is interpreted as a fixed capacity by setting `lb = ub = expression`.
`warmstart` is not supported when `expression` is provided.
`integer` is supported only when `expression` is a `GenericVariableRef`.
"""
function VariableCapacity(pname::String, modifier::Function; lb::Number=0., ub::Number=Inf, warmstart::Union{Nothing,Number}=nothing, unitsize::Union{Nothing,Number}=nothing, integer::Bool=false, expression::Union{Nothing,GenericVariableRef,GenericAffExpr,Number}=nothing)
    @argcheck lb >= 0. "Capacity cannot be negative"
    @argcheck lb <= ub "Lower bound is bigger than upper bound"
    if unitsize isa Number
        @argcheck unitsize > 0 "unitsize must be a strictly positive Number or nothing"
        unitsize = Float64(unitsize)
    end
    return _variablecapacity_from_expression(pname, modifier, Float64(lb), Float64(ub), warmstart, unitsize, integer, expression)
end

function _variablecapacity_from_expression(pname::String, modifier::Function, lb::Float64, ub::Float64, warmstart::Union{Nothing,Number}, unitsize::Union{Nothing,Float64}, integer::Bool, ::Nothing)
    @argcheck !integer || !isnothing(unitsize) "unitsize must be provided to activate an integer number of units"
    w = isnothing(warmstart) ? nothing : Float64(warmstart)
    return VariableCapacity{typeof(modifier),Nothing}(pname, modifier, lb, ub, w, unitsize, integer, nothing)
end

function _variablecapacity_from_expression(pname::String, modifier::Function, lb::Float64, ub::Float64, warmstart::Union{Nothing,Number}, unitsize::Union{Nothing,Float64}, integer::Bool, expression::GenericVariableRef)
    # reused variable: no warmstart here
    @argcheck isnothing(warmstart) "`warmstart` must be nothing when `expression` is provided"
    return VariableCapacity{typeof(modifier),GenericVariableRef}(pname, modifier, lb, ub, nothing, unitsize, integer, expression)
end

function _variablecapacity_from_expression(pname::String, modifier::Function, lb::Float64, ub::Float64, warmstart::Union{Nothing,Number}, unitsize::Union{Nothing,Float64}, integer::Bool, expression::GenericAffExpr)
    # affine expression is not a variable: no integer here
    @argcheck !integer "`integer` must be false when `expression` is provided"
    # no variable created here: no warmstart target
    @argcheck isnothing(warmstart) "`warmstart` must be nothing when `expression` is provided"
    return VariableCapacity{typeof(modifier),GenericAffExpr}(pname, modifier, lb, ub, nothing, unitsize, false, expression)
end

function _variablecapacity_from_expression(pname::String, modifier::Function, lb::Float64, ub::Float64, warmstart::Union{Nothing,Number}, unitsize::Union{Nothing,Float64}, integer::Bool, expression::Number)
    @argcheck isnothing(warmstart) "`warmstart` must be nothing when `expression` is provided"
    # Number input: fixed capacity (lb = ub = expression)
    # keep expr = nothing for the standard no expression path
    fixedvalue = Float64(expression)
    return VariableCapacity{typeof(modifier),Nothing}(pname, modifier, fixedvalue, fixedvalue, nothing, unitsize, false, nothing)
end

struct VariableCapacityBehavior{T<:VAL,M<:Function,E<:Union{Nothing,GenericVariableRef,GenericAffExpr}} <: AbstractSingleCapacityBehavior{T}
    data::VariableCapacity{M,E}
    val::T
end

# return a VariableCapacityBehavior
function buildbehavior(c::Component, b::VariableCapacity)    
    @argcheck hasport(c, b.pname) "Component does not have port named $(b.pname)"
    @argcheck hasmodifier(getport(c, b.pname), b.modifier) "Target port does not have the required modifier"
    return _buildbehavior_from_expr(c, b, b.expr)
end

# default case: no expression provided
function _buildbehavior_from_expr(c::Component, b::VariableCapacity, ::Nothing)
    if b.unitsize isa Number
        # variable is number of units
        v = @variable(uppermodel(sim(c)), base_name=name(c) * "_" * b.pname * "_" * modifiername(b.modifier) * "_" * "units" * "_" * sim(c).suffix, lower_bound=b.lb / b.unitsize, upper_bound=b.ub / b.unitsize, integer=b.integer, binary=false)
        # warmstart
        if !isnothing(b.warmstart)
            set_start_value(v, b.warmstart / b.unitsize)
        end
        
        e = v * b.unitsize
    else
        # variable is capacity
        v = @variable(uppermodel(sim(c)), base_name=name(c) * "_" * b.pname * "_" * modifiername(b.modifier) * "_" * "cap" * "_" * sim(c).suffix, lower_bound=b.lb, upper_bound=b.ub, integer=false, binary=false)
        
        # warmstart
        if !isnothing(b.warmstart)
            set_start_value(v, b.warmstart)
        end
        
        e = _to_affexpr(v, sim(c).model)
    end
    return VariableCapacityBehavior(b, e)
end

# expression case: direct variable reuse
function _buildbehavior_from_expr(c::Component, b::VariableCapacity, expr::GenericVariableRef)
    @argcheck isnothing(b.warmstart) "`warmstart` must be nothing when `expr` is provided"
    # apply integer on reused variable
    if b.integer
        set_integer(expr)
    end
    e = _to_affexpr(expr, sim(c).model)
    um = uppermodel(sim(c))
    @constraint(um, e >= b.lb)
    if b.ub < Inf
        @constraint(um, e <= b.ub)
    end
    return VariableCapacityBehavior(b, e)
end

# expression case: affine expression (integer unsupported)
function _buildbehavior_from_expr(c::Component, b::VariableCapacity, expr::GenericAffExpr)
    # affine expression: no integer support
    @argcheck !b.integer "`integer` must be false when `expr` is provided"
    @argcheck isnothing(b.warmstart) "`warmstart` must be nothing when `expr` is provided"
    e = _to_affexpr(expr, sim(c).model)
    um = uppermodel(sim(c))
    @constraint(um, e >= b.lb)
    if b.ub < Inf
        @constraint(um, e <= b.ub)
    end
    return VariableCapacityBehavior(b, e)
end

# for ProfileSource, we need to "apply" the behavior here
# the reason is that this behavior must be enforce before the call to other behaviors
# in particular: before call to VariableCost, which requires the flow being defined
function _addbehavior!(c::Component, b::VariableCapacityBehavior, m::ProfileSourceModel)
    @argcheck b.data.modifier == _defaultmodifier(carrierstyle(carrier(getport(c, _portname(b))))) "no modifier conversion allowed between component and capacity"
    c.model.s.output[PortRef(name(c), "output")].series .= _to_affexpr.(_capacity(b) * _profile(m), sim(c).model)
    push!(c.behaviors, b)
end

function _addbehavior!(c::Component, b::VariableCapacityBehavior, m::ProfileSinkModel)
    @argcheck b.data.modifier == _defaultmodifier(carrierstyle(carrier(getport(c, _portname(b))))) "no modifier conversion allowed between component and capacity"
    c.model.s.input[PortRef(name(c), "input")].series .= _to_affexpr.(_capacity(b) * _profile(m), sim(c).model)
    push!(c.behaviors, b)
end

"""
Apply capacity constraints.
"""

# general expression of capacity constraint
# can target model port or joint flow port
function __apply_constraint_general!(c::Component, b::VariableCapacityBehavior)
    @constraint(lowermodel(sim(c)), b.data.modifier(getport(c, b.data.pname)).data .<= _capacity(b))
end

# special case - profile models: behavior is enforced through _addbehavior!
function __apply_constraints_profile!(::Component, ::VariableCapacityBehavior) end

# general case: apply constraint at each timestep
# dispatch to either general case or model = profile case
function __apply_constraints!(c::Component, b::VariableCapacityBehavior)
    if (
        (model(c) isa ProfileSourceModel && _portname(b) == "output") ||
        (model(c) isa ProfileSinkModel && _portname(b) == "input")
    )
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

using JuMP: @variable, GenericAffExpr, set_start_value
using ArgCheck: @argcheck

"""
Behavior: variable composed capacity.

Constrains the sum of several target flows under one capacity variable.
"""

struct VariableComposedCapacity{M<:Function} <: AbstractCapacityData
    pname::Vector{String}
    modifier::M
    lb::Float64
    ub::Float64
    warmstart::Union{Nothing,Float64}
    unitsize::Union{Nothing,Float64}
    integer::Bool
end

"""
    VariableComposedCapacity(pname::Union{String,Vector{String}}, modifier::Function; lb::Number=0., ub::Number=Inf, warmstart::Union{Nothing,Number}=nothing, unitsize::Union{Nothing,Number}=nothing, integer::Bool=false)

Return `VariableComposedCapacity` behavior data associated with one or several port names `pname` and modifier `modifier`.
The capacity applies to the sum of targeted flows.
Optional parameters:
  * `lb`: lower bound
  * `ub`: upper bound
  * `warmstart`: initial value for the capacity variable
  * `unitsize`: size of one unit when considering a fleet
  * `integer`: if `unitsize` is a number, constrain the number of units to be integer
"""
function VariableComposedCapacity(pname::Union{String,Vector{String}}, modifier::Function; lb::Number=0., ub::Number=Inf, warmstart::Union{Nothing,Number}=nothing, unitsize::Union{Nothing,Number}=nothing, integer::Bool=false)
    _pname = pname isa String ? [pname] : copy(pname)
    @argcheck !isempty(_pname) "pname must contain at least one port name"
    @argcheck length(unique(_pname)) == length(_pname) "pname cannot contain duplicates"
    @argcheck lb >= 0. "Capacity cannot be negative"
    @argcheck lb <= ub "Lower bound is bigger than upper bound"
    if unitsize isa Number
        @argcheck unitsize > 0 "unitsize must be a strictly positive Number or nothing"
        unitsize = Float64(unitsize)
    end
    @argcheck !integer || !isnothing(unitsize) "unitsize must be provided to activate an integer number of units"
    w = isnothing(warmstart) ? nothing : Float64(warmstart)
    VariableComposedCapacity(_pname, modifier, Float64(lb), Float64(ub), w, unitsize, integer)
end

struct VariableComposedCapacityBehavior{T<:VAL,M<:Function} <: AbstractComposedCapacityBehavior{T}
    data::VariableComposedCapacity{M}
    val::T
end

# return a VariableComposedCapacityBehavior
function buildbehavior(c::Component, b::VariableComposedCapacity)
    @argcheck !(model(c) isa ProfileSourceModel) "Profile source model is not compatible with VariableComposedCapacity"
    for pname in b.pname
        @argcheck hasport(c, pname) "Component does not have port named $pname"
        @argcheck hasmodifier(getport(c, pname), b.modifier) "Target port $pname does not have the required modifier"
    end
    _pname = join(b.pname, "_")
    if b.unitsize isa Number
        # variable is number of units
        v = @variable(uppermodel(sim(c)), base_name=name(c) * "_" * _pname * "_" * modifiername(b.modifier) * "_" * "units" * "_" * sim(c).suffix, lower_bound=b.lb / b.unitsize, upper_bound=b.ub / b.unitsize, integer=b.integer, binary=false)
        # warmstart
        if !isnothing(b.warmstart)
            set_start_value(v, b.warmstart / b.unitsize)
        end
        e = v * b.unitsize
    else
        # variable is capacity
        v = @variable(uppermodel(sim(c)), base_name=name(c) * "_" * _pname * "_" * modifiername(b.modifier) * "_" * "cap" * "_" * sim(c).suffix, lower_bound=b.lb, upper_bound=b.ub, integer=false, binary=false)
        # warmstart
        if !isnothing(b.warmstart)
            set_start_value(v, b.warmstart)
        end
        e = _to_affexpr(v, sim(c).model)
    end
    return VariableComposedCapacityBehavior(b, e)
end

behaviorname(::VariableComposedCapacityBehavior) = "variable composed capacity"

# return the GenericAffExpr
_capacity(c::VariableComposedCapacityBehavior) = c.val

_portname(c::VariableComposedCapacityBehavior) = c.data.pname
_modifier(c::VariableComposedCapacityBehavior) = c.data.modifier

_unitsize(c::VariableComposedCapacityBehavior) = c.data.unitsize

# evaluate the number of units of the behavior
# return nothing if the unitsize is not defined
function _nbunits(c::VariableComposedCapacityBehavior)
    if isnothing(c.data.unitsize)
        return nothing
    else
        return _capacity(c) / _unitsize(c)
    end
end

# return the maximum number of units
_nbunitsmax(c::VariableComposedCapacityBehavior) = c.data.ub / _unitsize(c)

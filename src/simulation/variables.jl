using JuMP: @variable, VariableRef, GenericAffExpr
using ArgCheck: @argcheck

"""
Generation of time series bearing variables.
"""


"""
    Stepwise(s::Sim; lb=0., ub=Inf64, binary::Bool=false, integer::Bool=false, basename::String="")
Return a Stepwise vector populated with GenericAffExpr associated to a vector of variables
arguments: 
  * lb: lower bound
  * ub: upper bound
  * binary: variable is binary
  * integer: variable is integer
  * basename: variable base name (before numbering)
"""
function Stepwise(s::Sim; lb=0., ub=Inf64, binary::Bool=false, integer::Bool=false, basename::String="")

    @argcheck (!binary || !integer) "Variable cannot be both binary and integer"

    # checking types of bounds
    _checkcompatible(lb, s)
    _checkcompatible(ub, s)

    v = @variable(lowermodel(s), [1:nsteps(s)], binary=binary, integer=integer, base_name=basename*s.suffix)
    sl = Stepwise(lb, s.mesh)
    su = Stepwise(ub, s.mesh)   
    _set_bound_if_not_inf!.(sl, v, set_lower_bound)
    _set_bound_if_not_inf!.(su, v, set_upper_bound)
    sw = Stepwise(_to_affexpr(v, s.model), s.mesh)

    return sw
end

# check whether bound is compatible with time series (must be Number or vector of size nsteps or nhours matching s)
function _checkcompatible(bound, s::Sim)
    @argcheck (bound isa Number) || (length(bound) == nsteps(s)) || (length(bound) == nhours(s)) "Argument is not compatible with the time series (should be a Number, or an AbstractVector size $(nhours(s)) or $(nsteps(s)))"

    return nothing
end

# setboundf = set_lower_bound or set_upper_bound
function _set_bound_if_not_inf!(b, v::AbstractVariableRef,setboundf)
    if !isinf(b)
        setboundf(v,b)
    end
end

# accelerate sum of GenericAffExpr elements
# mutates e1 to add e2 (faster than create a new expression)
# return e1
function addto!(e1::GenericAffExpr, e2::Union{GenericAffExpr,Number})
    add_to_expression!(e1, e2)
    return e1
end

addto!(n1::Number, n2::Number) = n1 + n2
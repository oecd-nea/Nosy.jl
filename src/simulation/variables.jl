using JuMP: @variable, VariableRef
using ArgCheck: @argcheck

"""
Generation of time series bearing variables.
"""

function _checkcompatible(bound, s::Sim)
    @argcheck (bound isa Number) || (length(bound) == nsteps(s)) || (length(bound) == nhours(s)) "Argument is not compatible with the time series (should be a Number, or an AbstractVector size $(nhours(s)) or $(nsteps(s)))"

    return nothing
end

function _set_bound_if_not_inf(b, v::VariableRef,setboundf)
    if !isinf(b)
        setboundf(v,b)
    end
end

# Return a Stepwise vector populated with AffExpr associated to a vector of variables
# arguments: 
# lb: lower bound
# ub: upper bound
# binary: variable is binary
# integer: variable is integer
# basename: variable base name (before numbering)
function Stepwise(s::Sim; lb=0., ub=Inf64, binary::Bool=false, integer::Bool=false, basename::String="")

    @argcheck (!binary || !integer) "Variable cannot be both binary and integer"

    # checking types of bounds
    _checkcompatible(lb, s)
    _checkcompatible(ub, s)

    v = @variable(s.model, [1:nsteps(s)], binary=binary, integer=integer, base_name=basename)

    _set_bound_if_not_inf.(Stepwise(lb, s.mesh), v, set_lower_bound)
    _set_bound_if_not_inf.(Stepwise(ub, s.mesh), v, set_upper_bound)

    sw = Stepwise(_to_affexpr(v), s.mesh)

    return sw
end
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
  * mask: vector of booleans, variables are only created when true
"""
function Stepwise(s::Sim, mesh::RTimeMesh=s.mesh; lb=0., ub=Inf64, binary::Bool=false, integer::Bool=false, basename::String="", mask::Union{Nothing,AbstractVector{Bool}}=nothing)

    @argcheck (!binary || !integer) "Variable cannot be both binary and integer"
    @argcheck _compatiblemesh(s.mesh, mesh) "Variable mesh must be compatible with the simulation mesh"

    # checking types of bounds
    _checkcompatible(lb, mesh)
    _checkcompatible(ub, mesh)

    if isnothing(mask)
        v = @variable(lowermodel(s), [i=1:nsteps(mesh)], binary=binary, integer=integer, base_name=basename*s.suffix)
    else
        @argcheck length(mask) == nsteps(mesh) "mask is not compatible with mesh"
        v = @variable(lowermodel(s), [i=1:nsteps(mesh); mask[i]], binary=binary, integer=integer, base_name=basename*s.suffix)
    end

    sl = Stepwise(lb, mesh)
    su = Stepwise(ub, mesh)

    # cannot broadcase on a sparse axis array
    for i in eachindex(v) # index of a sparse axis array - it's actually a tuple, we only need the first (and only) itemi[1]
        _set_bound_if_not_inf!(sl[first(i)], v[i], set_lower_bound)
        _set_bound_if_not_inf!(su[first(i)], v[i], set_upper_bound)
    end

    sw = Stepwise(_to_affexpr(v, s.model), mesh)

    return sw
end

# check whether bound is compatible with time series (must be Number or vector of size nsteps or nhours matching s)
function _checkcompatible(bound, mesh::TimeMesh)
    @argcheck (bound isa Number) || (length(bound) == nsteps(mesh)) || (length(bound) == nhours(mesh)) "Argument is not compatible with the time series (should be a Number, or an AbstractVector size $(nhours(mesh)) or $(nsteps(mesh)))"

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

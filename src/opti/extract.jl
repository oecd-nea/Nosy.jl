"""
Extraction of solution.
"""

using JuMP: GenericAffExpr, value, is_solved_and_feasible
using JuMP: termination_status, OPTIMIZE_NOT_CALLED


"""
    extract(s::Snapshot)
Return a Snapshot populated with values corresponding to the optimized system.
"""
function extract(s::Snapshot{<:GenericAffExpr})
    m = sim(s).model
    if is_solved_and_feasible(m)
        return _extract(s)
    elseif termination_status(m) == OPTIMIZE_NOT_CALLED
        throw(AssertionError("Optimizer was not called"))
    else
        @warn "System is not optimized. Termination status: $(termination_status(m)). Returning the problem instead of the result."
        return s
    end
end
extract(::Snapshot{Float64}) = throw(ArgumentError("Snapshot is already extracted"))

"""
Special _extract methods.
"""

_extract(a::Number) = a
_extract(a::GenericAffExpr) = value(a)
_extract(a::Type{<:GenericAffExpr}) = Float64

_extract(a::Stepwise{<:GenericAffExpr}) = Stepwise(value.(a.data), a.mesh)
_extract(a::Stepwise{Float64}) = a

_extract(a::Port{Float64}) = a
_extract(a::Port{<:GenericAffExpr}) = Port(carrier(a), _extract(series(a)), a.used)

_extract(a::String) = a
_extract(a::Symbol) = a

_extract(a::Sim) = a
_extract(a::AbstractCarrier) = a
_extract(a::Base.RefValue{Bool}) = a
_extract(a::Function) = a

_extract(v::AbstractVector) = typeof(v).name.wrapper(_extract.(v))
_extract(v::AbstractVector{Float64}) = v

# preserve vector eltype for abstract eltype
_extract(v::Vector{<:AbstractJointFlow}) = convert(Vector{AbstractJointFlow{Float64}}, _extract.(v))
_extract(v::Vector{<:AbstractRegularBehavior}) = convert(Vector{AbstractRegularBehavior{Float64}}, _extract.(v))

_extract(d::AbstractDict) = typeof(d).name.wrapper(k => _extract(v) for (k,v) in d)
_extract(d::Dict{String,<:Component}) = Dict{String,Component{Float64}}(k => _extract(v) for (k,v) in d)
_extract(d::Dict{String,<:Node}) = Dict{String,Node{Float64}}(k => _extract(v) for (k,v) in d)
_extract(d::Dict{PortRef,<:Port}) = Dict{PortRef,Port{Float64}}(k => _extract(v) for (k,v) in d)

# dual price
_extract(a::DualPrice{<:GenericAffExpr}) = _dualprice(a) # defined in post

"""
General _extract methods.
"""

_extract(a::AbstractElement{<:GenericAffExpr}) = typeof(a).name.wrapper((_extract(getproperty(a, p)) for p in propertynames(a))...)
_extract(a::AbstractElement{Float64}) = a

"""
Fallback.
"""
_extract(a) = a

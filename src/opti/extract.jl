"""
Extraction of solution.
"""

using JuMP: AffExpr, value, is_solved_and_feasible

"""
    extract(s::Snapshot)
Return a Snapshot populated with values corresponding to the optimized system.
"""
function extract(s::Snapshot{AffExpr})
    @assert is_solved_and_feasible(sim(s).model) "System is not optimized"
    return _extract(s)
end
extract(::Snapshot{Float64}) = throw(ArgumentError("Snapshot is already extracted"))

"""
Special _extract methods.
"""

_extract(a::Number) = a
_extract(a::AffExpr) = value(a)
_extract(a::Type{AffExpr}) = Float64

_extract(a::Stepwise{AffExpr}) = Stepwise(value.(a.data), a.mesh)
_extract(a::Stepwise{Float64}) = a

_extract(a::Port{Float64}) = a
_extract(a::Port{AffExpr}) = Port(carrier(a), _extract(series(a)), a.used)

_extract(a::String) = a
_extract(a::Symbol) = a

_extract(a::Sim) = a
_extract(a::AbstractCarrier) = a
_extract(a::Base.RefValue{Bool}) = a

_extract(v::AbstractVector) = typeof(v).name.wrapper(_extract.(v))
_extract(v::AbstractVector{Float64}) = v

# preserve vector eltype for abstract eltype
_extract(v::Vector{AbstractJointFlow{AffExpr}}) = convert(Vector{AbstractJointFlow{Float64}}, _extract.(v))
_extract(v::Vector{AbstractRegularBehavior{AffExpr}}) = convert(Vector{AbstractRegularBehavior{Float64}}, _extract.(v))

_extract(d::AbstractDict) = typeof(d).name.wrapper(k => _extract(v) for (k,v) in d)
_extract(d::Dict{String,Component{AffExpr}}) = Dict{String,Component{Float64}}(k => _extract(v) for (k,v) in d)
_extract(d::Dict{String,Node{AffExpr}}) = Dict{String,Node{Float64}}(k => _extract(v) for (k,v) in d)
_extract(d::Dict{String,Port{AffExpr}}) = Dict{String,Port{Float64}}(k => _extract(v) for (k,v) in d)

# dual price
_extract(a::DualPrice{AffExpr}) = _dualprice(a) # defined in post

"""
General _extract methods.
"""

_extract(a::AbstractElement{AffExpr}) = typeof(a).name.wrapper((_extract(getproperty(a, p)) for p in propertynames(a))...)
_extract(a::AbstractElement{Float64}) = a
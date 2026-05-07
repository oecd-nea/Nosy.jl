"""
Extraction of solution.
"""

using JuMP: GenericAffExpr, GenericVariableRef, value
using JuMP: termination_status, OPTIMIZE_NOT_CALLED
using ConstructionBase: constructorof


"""
    extract(s::Snapshot)

Return a Snapshot populated with values corresponding to the optimised system.
"""
function extract(s::Snapshot{<:GenericAffExpr})
    m = sim(s).model
    if issolvedandfeasible(m)
        return _extract(s)
    elseif termination_status(m) == OPTIMIZE_NOT_CALLED
        throw(AssertionError("Optimizer was not called"))
    else
        @warn "System is not optimised. Termination status: $(termination_status(m)). Returning the problem instead of the result."
        return s
    end
end
extract(::Snapshot{Float64}) = throw(ArgumentError("Snapshot is already extracted"))

"""
Special _extract methods.
"""

_extract(a::Number) = a
_extract(a::GenericAffExpr) = value(a)
_extract(a::GenericVariableRef) = value(a)
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

_extract(v::AbstractVector) = constructorof(typeof(v))(_extract.(v))
_extract(v::AbstractVector{Float64}) = v

# preserve vector eltype for abstract eltype
_extract(v::Vector{<:AbstractJointFlow}) = convert(Vector{AbstractJointFlow{Float64}}, _extract.(v))
_extract(v::Vector{<:AbstractRegularBehavior}) = convert(Vector{AbstractRegularBehavior{Float64}}, _extract.(v))

_extract(d::AbstractDict) = constructorof(typeof(d))(k => _extract(v) for (k,v) in d)
_extract(d::Dict{String,<:Component}) = Dict{String,Component{Float64}}(k => _extract(v) for (k,v) in d)
_extract(d::Dict{String,<:Node}) = Dict{String,Node{Float64}}(k => _extract(v) for (k,v) in d)
_extract(d::Dict{PortRef,<:Port}) = Dict{PortRef,Port{Float64}}(k => _extract(v) for (k,v) in d)

_extract(a::VariableCapacity{M,<:Union{GenericAffExpr,GenericVariableRef}}) where {M} =
    VariableCapacity{M,Nothing}(a.pname, a.modifier, a.lb, a.ub, a.warmstart, a.unitsize, a.integer, nothing)

# dual price
_extract(a::SavedDualPrice{<:GenericAffExpr}) = _dualprice(a) # defined in post

"""
General _extract methods.
"""

_extract_fields(a) = (_extract(getfield(a, f)) for f in fieldnames(typeof(a)))

_rebuild_extracted(a, fields...) = constructorof(typeof(a))(fields...)

_extract(a::AbstractElement{<:GenericAffExpr}) = _rebuild_extracted(a, _extract_fields(a)...)
_extract(a::AbstractElement{Float64}) = a

"""
Fallback.
"""
_extract(a) = a

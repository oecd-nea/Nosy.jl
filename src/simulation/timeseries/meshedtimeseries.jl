
using ArgCheck
using JuMP: GenericAffExpr, VariableRef
using OrderedCollections: OrderedDict

abstract type AbstractMeshedTimeSeries{T} <: AbstractTimeSeries{T} end

parenttype(s::AbstractMeshedTimeSeries) = (typeof(s)).name.wrapper
iscircular(s::AbstractMeshedTimeSeries) = iscircular(s.mesh)

"""
AbstractMeshedTimeSeries interface (on top of AbstractTimeSeries)
"""

Base.copy(s::AbstractTimeSeries) = typeof(s)(copy(parent(s)), s.mesh)
Base.similar(s::AbstractTimeSeries) = typeof(s).name.wrapper(similar(parent(s)), s.mesh)
Base.zero(s::AbstractTimeSeries{T}) where T = fill!(similar(s), zero(T))

"""
AbstractMeshedTimeSeries algebra.
"""


"""
Addition operator for AbstractMeshedTimeSeries.
"""
function Base.:+(s1::T, s2::T) where T<:AbstractMeshedTimeSeries  
    @argcheck s1.mesh == s2.mesh "Time series must be associated with the same mesh"
    return T.name.wrapper(s1.data + s2.data, s1.mesh)
end

# Addition of different types of time series is forbidden
function Base.:+(s1::T1, s2::T2) where {T1<:AbstractMeshedTimeSeries, T2<:AbstractMeshedTimeSeries}
    @argcheck parenttype(s1) == parenttype(s2) "Time series have different types"
    return +(promote(s1, s2)...)
end

"""
Multiplication by scalar operator for AbstractMeshedTimeSeries.
"""
Base.:*(s::AbstractMeshedTimeSeries, n::Number) = typeof(s).name.wrapper(s.data * n, s.mesh)

"""
Commutativity of multiplication by scalar operator for AbstractMeshedTimeSeries..
"""
Base.:*(n::Number, s::AbstractMeshedTimeSeries) = s * n

"""
Subtraction operator for AbstractMeshedTimeSeries.
"""
Base.:-(s1::T1, s2::T2) where {T1<:AbstractMeshedTimeSeries, T2<:AbstractMeshedTimeSeries} = s1 + (-1 * s2)

"""
Division by scalar operator for AbstractMeshedTimeSeries.
"""
Base.:/(s::AbstractMeshedTimeSeries, n::Number) = typeof(s).name.wrapper(s.data / n, s.mesh)

# conversion of Number to Float64 to keep symmetry between Hourly and Stepwise and simplify types
_toVal(v::AbstractVector{Nothing}) = v
_toVal(v::AbstractVector{Bool}) = v
_toVal(v::AbstractVector{Float64}) = v
_toVal(v::AbstractVector{<:Number}) = Float64.(v)
_toVal(v::AbstractVector{<:GenericAffExpr}) = convert(Vector{eltype(v)}, v)
_toVal(v::AbstractVector{VariableRef}) = convert(Vector{VariableRef}, v)

# Stepwise: time series based on a timestep possibly inferior to hour
struct Stepwise{T} <: AbstractMeshedTimeSeries{T}
    data::Vector{T}
    mesh::RTimeMesh

    """
        Stepwise(v::AbstractVector, mesh::TimeMesh)
    Return a Stepwise time series based on vector `v` and mesh `mesh`.
    """
    function Stepwise(v::AbstractVector{T}, m::TimeMesh) where T
        l = length(v)
        @argcheck l == nsteps(m) || l == nhours(m) "The provided time series does not have the correct number of steps ($(length(v)) instead of $(nsteps(m)) or $(nhours(m)))"
        _data = _toVal(v)
        if length(v) == nsteps(m)
            return new{eltype(_data)}(_data,m)
        elseif length(v) == nhours(m)
            return Stepwise(Hourly(_data, m))
        end
    end
end

"""
    Stepwise(d::OrderedDict{Int64,T}, m::TimeMesh) where T
Build a Stepwise form an OrderedDict. Used as an intermediate step for SparseAxisArray.
"""
function Stepwise(d::OrderedDict{Int64,T}, m::TimeMesh) where T
    s = differentzerovector(T, nsteps(m))
    for i in eachstep(m)
        if haskey(d,i)
            s[i] = d[i]
        end
    end
    return Stepwise(s, m)
end

mesh(s::Stepwise) = s.mesh

"""
    Stepwise(v::Number, mesh::TimeMesh)
Return a Stepwise time series based on Number `v` and mesh `mesh`.    
"""
Stepwise(v::Number, m::TimeMesh) = Stepwise(fill(Float64(v), nsteps(m)), m)


import Base: promote_rule, convert
promote_rule(::Type{Stepwise{T}}, ::Type{Stepwise{S}}) where {T,S} = Stepwise{promote_type(T,S)} # no need to add symmetrical function (handled by promote_type)
convert(::Type{Stepwise{T}}, s::Stepwise) where T = Stepwise(convert.(T, s.data), s.mesh)

# Hourly: time series based on a hourly timestep
struct Hourly{T} <: AbstractMeshedTimeSeries{T}
    data::Vector{T}
    mesh::RTimeMesh

    """
        Hourly(v, mesh::TimeMesh)
    Return a Hourly time series based on vector `v` and mesh `mesh`.
    """
    function Hourly(v::AbstractVector{T}, m::TimeMesh) where T
        @argcheck length(v) == nhours(m) "The provided time series does not have the correct number of steps ($(length(v)) instead of $(nhours(m)))"
        data = _toVal(v)
        new{eltype(data)}(data, m)
    end
end

mesh(s::Hourly) = s.mesh

function shift(s::AbstractMeshedTimeSeries, i::Int)
    if iscircular(s)
        return @view s[begin+i:end+i]
    end
    first = firstindex(s)
    last = lastindex(s)
    shifted_indices = clamp.(collect(eachindex(s)) .+ i, first, last)
    return typeof(s).name.wrapper(parent(s)[shifted_indices], s.mesh)
end

nhours(s::AbstractMeshedTimeSeries) = nhours(s.mesh)
nsteps(s::AbstractMeshedTimeSeries) = nsteps(s.mesh)

eachhour(s::AbstractMeshedTimeSeries) = eachhour(s.mesh)
eachstep(s::AbstractMeshedTimeSeries) = eachstep(s.mesh)



"""
Convention for Hourly / Stepwise approach: the "power" approach is used. 
  * The conservation is of instantaneous power at the time interval bounds.
  * The conservation of the integral over the intervals is not applied.
In case the timestep duration is sub-hour, the hour -> step conversion considers linear variation of the quantity over the hour.
"""

"""
    Hourly(s::Stepwise{T}) where T
Convert a Stepwise time series `s` into a Hourly.
"""
function Hourly(s::Stepwise{T}) where T
    if isunit(s.mesh)
        return Hourly(s.data, s.mesh) # faster conversion in case mesh is trivial
    else
        # Step values are attached to timestep bounds. If a timestep is longer
        # than one hour, interpolate linearly at skipped integer hours.
        v = [_stepwise_at_hour(s, h) for h in eachhour(s)]
        return Hourly(v, s.mesh)
    end
end

function _stepwise_at_hour(s::Stepwise, h::Int)
    st = step(s.mesh, h - 1) # hour value is hour index - 1
    curh = hour(s.mesh, st)
    r = (h - curh) / weight(s.mesh, st)
    iszero(r) && return s[st]
    next = iscircular(s) ? st + 1 : min(st + 1, lastindex(s))
    return (1 - r) * s[st] + r * s[next]
end

# VariableRef is not closed under interpolation: an exact boundary would return
# a VariableRef, while an interpolated value returns an AffExpr. Always using
# the affine expression form keeps the resulting Hourly vector type-stable.
function _stepwise_at_hour(s::Stepwise{<:VariableRef}, h::Int)
    st = step(s.mesh, h - 1) # hour value is hour index - 1
    curh = hour(s.mesh, st)
    r = (h - curh) / weight(s.mesh, st)
    next = iscircular(s) ? st + 1 : min(st + 1, lastindex(s))
    return (1 - r) * s[st] + r * s[next]
end

"""
    Stepwise(h::Hourly{T}) where T
Convert a Hourly time series `h` into a Stepwise.
"""
function Stepwise(h::Hourly{T}) where T
    if isunit(h.mesh)
        return Stepwise(h.data, h.mesh) # faster conversion in case mesh is trivial
    else
        # hypothesis: linear trend during the hour
        # this also includes between last and first step
        v = Vector{T}(undef, nsteps(h))
        for s in eachstep(h)
            curh = hour(h.mesh, s)
            if isinteger(curh)
                v[s] = h[Int(curh)]
            else
                icurh = Int(floor(curh))
                next = iscircular(h) ? icurh + 1 : min(icurh + 1, lastindex(h))
                v[s] = (icurh + 1 - curh) * h[icurh] + (curh - icurh) * h[next]
            end
        end
        return Stepwise(v, h.mesh)
    end
end

Base.convert(::Type{Vector{T}}, s::AbstractTimeSeries{T}) where T = parent(s)


# The sum of a Stepwise series is evaluated as the trapezoid integral of stepwise elements following timesteps durations.
# Because model assumes that quantities are linear between instants
function Base.sum(s::Stepwise{<:GenericAffExpr})
    _res = zero(eltype(s))
    if iscircular(s)
        for i in eachindex(s)
            add_to_expression!(_res, s[i] * (weight(s.mesh, i-1) + weight(s.mesh, i)) / 2)
        end
    else
        for i in firstindex(s):(lastindex(s)-1)
            add_to_expression!(_res, (s[i] + s[i+1]) * weight(s.mesh, i) / 2)
        end
    end
    return _res
end

function Base.sum(s::Stepwise{Float64})
    if iscircular(s)
        return sum(s.data[i] * (weight(s.mesh, i-1) + weight(s.mesh, i)) / 2 for i in eachindex(s.data))
    else
        return sum((s.data[i] + s.data[i+1]) * weight(s.mesh, i) / 2 for i in firstindex(s):(lastindex(s)-1))
    end
end

# The sum of a Hourly is a regular sum
# We use addto! just to make it faster, it doesn't change the result
function Base.sum(h::Hourly{<:GenericAffExpr})
    _res = zero(eltype(h))
    for e in h
        add_to_expression!(_res, e)
    end
    return _res    
end

Base.sum(s::Hourly{Float64}) = sum(s.data)

# Cross-mesh operations are only defined from a source mesh to an equal or
# coarser target mesh with the same horizon and aligned boundaries.
_mesh_ends(m::TimeMesh) = cumsum(parent(weight(m)))
_stepstart(ends, i::Int) = i == 1 ? zero(eltype(ends)) : ends[i - 1]
_intervals(m::TimeMesh) = 1:(iscircular(m) ? nsteps(m) : nsteps(m) - 1)

function _containsmesh(source::TimeMesh, target::TimeMesh)
    source == target && return true
    nhours(source) == nhours(target) || return false
    iscircular(source) == iscircular(target) || return false

    source_ends = _mesh_ends(source)
    target_ends = _mesh_ends(target)
    i = firstindex(source_ends)
    for b in target_ends
        while i <= lastindex(source_ends) && source_ends[i] < b
            i += 1
        end
        (i <= lastindex(source_ends) && source_ends[i] == b) || return false
    end
    return true
end

# Non-directional mesh compatibility: the meshes share horizon/circularity and
# one mesh's boundaries are nested in the other's. 
# Use `_containsmesh(source, target)` when projection direction matters.
_compatiblemesh(m1::TimeMesh, m2::TimeMesh) = _containsmesh(m1, m2) || _containsmesh(m2, m1)

"""
    remesh(s::Stepwise, mesh::TimeMesh)

Remesh a continuous `Stepwise` series onto a compatible coarser mesh while
preserving its integral.
"""
function remesh(s::Stepwise{T}, target::TimeMesh) where T
    source = mesh(s)
    source == target && return s
    @argcheck _containsmesh(source, target) "Target mesh must have the same horizon, matching circularity, and aligned boundaries with source mesh"
    v = differentzerovector(T, nsteps(target))
    target_ends = _mesh_ends(target)
    source_ends = _mesh_ends(source)

    ti = first(_intervals(target))
    for si in _intervals(source)
        sstart = _stepstart(source_ends, si)
        while sstart >= target_ends[ti]
            ti += 1
        end
        v[ti] = addto!(v[ti], (s[si] + s[si + 1]) * weight(source, si) / (2 * integrationweight(target, ti)))
    end
    return Stepwise(v, target)
end

function _sum_to_mesh(series, target::TimeMesh, ::Type{T}) where T
    total = Stepwise(differentzerovector(T, nsteps(target)), target)
    for s in series
        total.data .= addto!.(total.data, remesh(s, target).data)
    end
    return total
end


# Broadcasting interface
# https://docs.julialang.org/en/v1/manual/interfaces/
Base.BroadcastStyle(::Type{<:Stepwise}) = Broadcast.ArrayStyle{Stepwise}()
Base.broadcastable(s::Stepwise) = s

find_stepwise(bc::Base.Broadcast.Broadcasted) = find_stepwise(bc.args)
find_stepwise(args::Tuple) = find_stepwise(args[1], Base.tail(args))
find_stepwise(x) = x
find_stepwise(::Tuple{}) = nothing
find_stepwise(s::Stepwise, rest) = s
find_stepwise(::Any, rest) = find_stepwise(rest)

function find_stepwise(bc::Broadcast.Broadcasted{Broadcast.ArrayStyle{Stepwise}}, rest)
    v = find_stepwise(bc)
    if isnothing(v)
        find_stepwise(rest)
    end
    return v
end

function Base.similar(bc::Broadcast.Broadcasted{Broadcast.ArrayStyle{Stepwise}}, ::Type{ElType}) where ElType
    # scan bc for the Stepwise to get its mesh
    s = find_stepwise(bc)
    return Stepwise(similar(Vector{ElType}, axes(bc)), s.mesh)
end

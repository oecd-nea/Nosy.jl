
using ArgCheck
using JuMP: AffExpr

abstract type AbstractMeshedTimeSeries{T} <: AbstractTimeSeries{T} end


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
    @argcheck s1.mesh === s2.mesh "Time series are associated with the same mesh"
    return T.name.wrapper(s1.data + s2.data, s1.mesh)
end

# Addition of different types of time series is forbidden
Base.:+(::T1, ::T2) where {T1<:AbstractMeshedTimeSeries, T2<:AbstractMeshedTimeSeries}  = error("Time series have different types")

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
_toVal(v::AbstractVector{<:Number}) = Float64.(v)
_toVal(v::AbstractVector{AffExpr}) = convert(Vector{AffExpr}, v)

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

mesh(s::Stepwise) = s.mesh

"""
    Stepwise(v::Number, mesh::TimeMesh)
Return a Stepwise time series based on Number `v` and mesh `mesh`.    
"""
Stepwise(v::Number, m::TimeMesh) = Stepwise(fill(Float64(v), nsteps(m)), m)

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
    # this sense is straightforward as all (integer) hours are contained in steps
    v = Vector{T}(undef,nhours(s))
    for h in eachhour(s)
        v[h] = s[step(s.mesh,h)]
    end
    return Hourly(v, s.mesh)
end

"""
    Stepwise(h::Hourly{T}) where T
Convert a Hourly time series `h` into a Stepwise.
"""
function Stepwise(h::Hourly{T}) where T
    # hypothesis: linear trend during the hour
    # this also includes between last and first step
    v = Vector{T}(undef, nsteps(h))
    for s in eachstep(h)
        curh = hour(h.mesh, s)
        if isinteger(curh)
            v[s] = h[Int(curh)]
        else
            icurh = Int(floor(curh))
            v[s] = (icurh + 1 - curh) * h[icurh] + (curh - icurh) * h[icurh+1]
        end
    end
    return Stepwise(v, h.mesh)
end

Base.convert(::Type{Vector{T}}, s::AbstractTimeSeries{T}) where T = parent(s)


# The sum of a Stepwise series is evaluated as the sum of the Hourly series.
# The sum is actually the sum weighted by the timesteps durations.
Base.sum(s::Stepwise) = sum(Hourly(s))
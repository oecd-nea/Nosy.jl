
using ArgCheck

abstract type AbstractMeshedTimeSeries{T} <: AbstractTimeSeries{T} end

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


# Stepwise: time series based on a timestep possibly inferior to hour
struct Stepwise{T} <: AbstractMeshedTimeSeries{T}
    data::Vector{T}
    mesh::RTimeMesh

    """
        Stepwise(v, mesh::TimeMesh)
    Return a Stepwise time series based on vector `v` and mesh `mesh`.
    """
    function Stepwise(v::AbstractVector{T}, m::TimeMesh) where T
        @assert length(v) == nsteps(m) "The provided time series does not have the correct number of steps ($(length(v)) instead of $(nsteps(m)))"
        data = convert(Vector{T}, v)
        new{T}(data, m)
    end
end

# Hourly: time series based on a hourly timestep
struct Hourly{T} <: AbstractMeshedTimeSeries{T}
    data::Vector{T}
    mesh::RTimeMesh

    """
        Hourly(v, mesh::TimeMesh)
    Return a Hourly time series based on vector `v` and mesh `mesh`.
    """
    function Hourly(v::AbstractVector{T}, m::TimeMesh) where T
        @assert length(v) == nhours(m) "The provided time series does not have the correct number of steps ($(length(v)) instead of $(nhours(m)))"
        data = convert(Vector{T}, v)
        new{T}(data, m)
    end
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
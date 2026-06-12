using ArgCheck
import Base: ==

"""
    GenericTimeSeries{T}

Basic implementation of `AbstractTimeSeries`. Used as a base for `TimeMesh`.
Algebraic operations are not implemented for `GenericTimeSeries`.
"""
struct GenericTimeSeries{T} <: AbstractTimeSeries{T}
    data::Vector{T}
    circular::Bool
end

GenericTimeSeries(v::Vector{T}) where T = GenericTimeSeries{T}(v, true)
iscircular(s::GenericTimeSeries) = s.circular

Base.copy(s::GenericTimeSeries) = GenericTimeSeries(copy(parent(s)), iscircular(s))
Base.similar(s::GenericTimeSeries) = GenericTimeSeries(similar(parent(s)), iscircular(s))
Base.zero(s::GenericTimeSeries{T}) where T = GenericTimeSeries(differentzerovector(T, length(s)), iscircular(s))


# Contain the time structure of the model and convert between time series types.
# TimeMesh() creates an 8760-hour mesh with one step per hour.
struct TimeMesh{T}
    weight::GenericTimeSeries{T}
    nstep::Int64
    nhour::Int64
    hour_at_step::GenericTimeSeries{T} # vector of size nstep, hour index as a function of step index
    step_at_hour::GenericTimeSeries{Int64} # vector of size nhour, step index as a function of hour index
    isunit::Bool # true when every timestep weight is one hour (fast path for step conversion)
    circular::Bool
end

const RTimeMesh = TimeMesh{Rational{Int64}} # enforce parametric type of mesh in the general case to avoid parameterizing AbstractMeshedTimeSeries

"""
    TimeMesh(w::Vector; circular::Bool=true)

Return a `TimeMesh` based on the timestep weight vector `w`. 
All weights must be positive rational or integer values, and their sum must be an integer.
Time meshes are circular by default. Pass `circular=false` to make associated
time series reject out-of-bounds indexing instead of wrapping around.
"""
function TimeMesh(w::Vector{T}; circular::Bool=true) where T
    
    @argcheck !isempty(w) "Please use a non-empty weight series"

    @argcheck all(x -> !(x isa Bool) && (x isa Integer || x isa Rational), w) "Please only use rational or integer weights"

    _w = Rational{Int64}.(w)

    @argcheck isinteger(sum(_w)) "Please use a weight series with integer sum"

    @argcheck all(_w .> 0//1) "Please only use positive rational or integer weights"

    nstep = length(_w)
    nhour = Int(sum(_w))

    @argcheck circular || nstep > 1 "Non-circular time meshes must contain at least two steps"

    hour_at_step = Vector{Rational{Int64}}(undef, nstep)
    step_at_hour = Vector{Int64}(undef, nhour)

    hour_at_step[1] = 1//1
    step_at_hour[1] = 1

    local h = 1//1 # current hour
    for s in 2:nstep # iterate over step index
        h = h + _w[s-1]
        hour_at_step[s] = h #floor(h)
    end

    local s = 1
    for h in eachindex(step_at_hour)
        while s < nstep && hour_at_step[s+1] <= h
            s += 1
        end
        step_at_hour[h] = s
    end

    return TimeMesh(
        GenericTimeSeries(_w, circular), 
        nstep, 
        nhour, 
        GenericTimeSeries(hour_at_step, circular), 
        GenericTimeSeries(step_at_hour, circular),
        all(_w .== 1//1),
        circular
    )
end

"""
    TimeMesh(; circular::Bool=true)

Return a `TimeMesh` based on the a 8760 1-hour timesteps.
Time meshes are circular by default. Pass `circular=false` to make associated
time series reject out-of-bounds indexing instead of wrapping around.
"""
TimeMesh(; circular::Bool=true) = TimeMesh(fill(1//1, 8760), circular=circular)

nhours(m::TimeMesh) = m.nhour
nsteps(m::TimeMesh) = m.nstep

weight(m::TimeMesh) = m.weight
weight(m::TimeMesh, step::Int) = m.weight[iscircular(m) ? step : clamp(step, firstindex(m.weight), lastindex(m.weight))]

function integrationweight(m::TimeMesh, i::Int)
    if iscircular(m)
        return Float64((weight(m, i - 1) + weight(m, i)) / 2)
    elseif nsteps(m) == 1
        return Float64(weight(m, i))
    elseif i == 1
        return Float64(weight(m, i) / 2)
    elseif i == nsteps(m)
        return Float64(weight(m, i - 1) / 2)
    else
        return Float64((weight(m, i - 1) + weight(m, i)) / 2)
    end
end

# Important note: 
# hour index denotes the number of the current hour, as vector index, starting at 1
# hour value denotes the actual value of the current hour, starting at 0
# in a year, the hour index is between 1:8760
# in a year, the hour value is between 0:8759
# hour value at index 1 is 0: "the first hour of the year is between 00:00 and 01:00"

hour(m::TimeMesh, step::Int) = m.hour_at_step[step] # hour INDEX at a given step
step(m::TimeMesh, hour::Int) = m.step_at_hour[hour+1] # step at a given hour VALUE

eachhour(m) = eachindex(m.step_at_hour)
eachstep(m) = eachindex(m.hour_at_step)

isunit(m::TimeMesh) = m.isunit
iscircular(m::TimeMesh) = m.circular

function ==(t1::TimeMesh, t2::TimeMesh)
    (t1 === t2) && return true # this is the same time mesh (normal case, only 1 sim)
    return t1.circular == t2.circular && nsteps(t1) == nsteps(t2) && parent(weight(t1)) == parent(weight(t2))
end

# display mesh info
function Base.show(io::IO, m::TimeMesh)
    nh = nhours(m)
    ns = nsteps(m)
    print(
        io, 
        "Time mesh ($nh hours, $ns steps, $(iscircular(m) ? "circular" : "non-circular"))"
    )
end

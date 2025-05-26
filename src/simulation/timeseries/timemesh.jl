using ArgCheck
 
"""
    GenericTimeSeries{T}
Basic implementation of the AbstractTimeSeries. Used as a base for the TimeMesh.
Algebra properties not implemented for GenericTimeSeries.
"""
struct GenericTimeSeries{T} <: AbstractTimeSeries{T}
    data::Vector{T}
end

"""
    TimeMesh{T}
Contain the time structure of the model; is used for conversion between different time series types.
"""
struct TimeMesh{T}
    weight::GenericTimeSeries{T}
    nstep::Int64
    nhour::Int64
    hour_at_step::GenericTimeSeries{T} # vector of size nstep, hour index as a function of step index
    step_at_hour::GenericTimeSeries{Int64} # vector of size nhour, step index as a function of hour index
    isunit::Bool
end

const RTimeMesh = TimeMesh{Rational{Int64}} # enforce parametric type of mesh in the general case to avoid parameterizing AbstractMeshedTimeSeries

"""
    TimeMesh(w::Vector{Int})
Return a TimeMesh based on the timestep weight vector `w`.
"""
function TimeMesh(w::Vector{T}) where T
    
    @argcheck isinteger(sum(w)) "Please use a weight series with integer sum"

    @argcheck all(w .> 0. .&& w .<= 1.) "Please only use rational or integer weights in ]0., 1]"

    nstep = length(w)
    nhour = Int(sum(w))

    hour_at_step = Vector{T}(undef, nstep)
    step_at_hour = Vector{Int64}(undef, nhour)

    hour_at_step[1] = T(1)
    step_at_hour[1] = 1

    local h = T(1) # current hour
    for s in 2:nstep # iterate over step index
        h = h + w[s-1]
        hour_at_step[s] = h #floor(h)
        if floor(hour_at_step[s]) != floor(hour_at_step[s-1])
            step_at_hour[Int(hour_at_step[s])] = s
        end
    end

    return TimeMesh(
        GenericTimeSeries(w), 
        nstep, 
        nhour, 
        GenericTimeSeries(hour_at_step), 
        GenericTimeSeries(step_at_hour),
        all(w .== 1//1)
    )
end

# default TimeMesh (8760 hours, 1 step per hour)
TimeMesh() = TimeMesh(fill(1//1, 8760))

nhours(m::TimeMesh) = m.nhour
nsteps(m::TimeMesh) = m.nstep

weight(m::TimeMesh) = m.weight
weight(m::TimeMesh, step::Int) = m.weight[step]

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

import Base: ==
function ==(t1::TimeMesh, t2::TimeMesh)
    (t1 === t2) && return true # this is the same time mesh (normal case, only 1 sim)
    return all(t1.weight .== t2.weight) # very inefficient, but rare (cross-sim)
end

# display mesh info
function Base.show(io::IO, m::TimeMesh)
    nh = nhours(m)
    ns = nsteps(m)
    print(
        io, 
        "Time mesh ($nh hours, $ns steps)"
    )
end
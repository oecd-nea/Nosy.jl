using ArgCheck: @argcheck

abstract type AbstractUnitCommitmentData <: AbstractBehaviorData end

"""
Behavior: unit commitment for fleet of components.
"""

struct UnitCommitment <: AbstractUnitCommitmentData
    pname::String
    minratio::Float64
    startup::Float64
    shutdown::Float64
    uptime::Float64
    downtime::Vector{Float64}
    startupratio::Float64
    shutdownratio::Float64
    integer::Bool
end

"""
    UnitCommitment(pname::String, minratio::Number; startup::Number=0, shutdown::Number=0, uptime::Number=0, downtime::Number=0, startupratio::Number=minratio, shutdownratio::Number=minratio, integer::Bool=false)
Return a UnitCommitment behavior related to port `pname`, with minimum flow ratio `minratio`.
Optional parameters:
  * startup: startup duration in hours (default=0).
  * shutdown: shutdown duration in hours (default=0).
  * uptime:: minimum uptime duration in hours (default=0).
  * downtime: minimum downtime duration in hours (default=0).
  * startupratio: flow ratio at the end of the startup phase (default=minratio)
  * shutdownratio: flow ratio at the beginning of the shutdown phase (default=minratio)
  * integer: whether the unit commitment must follow an integer constraint (default=false).
"""
function UnitCommitment(pname::String, minratio::Number; startup::Number=0, shutdown::Number=0, uptime::Number=0, downtime=0, startupratio::Number=minratio, shutdownratio::Number=minratio, integer::Bool=false)
    @argcheck 0 <= minratio <= 1. "minratio must be between 0 and 1."
    @argcheck startup >= 0 && shutdown >= 0 && uptime >= 0 "All durations must be superior or equal to zero"
    if downtime isa Number
        @argcheck downtime >= 0 "All durations must be superior or equal to zero"
        downtime = [downtime]
    elseif downtime isa Vector{<:Number}
        @argcheck length(downtime) >= 1 "At least one downtime duration must be specified"
        @argcheck all(downtime .>= 0) "All durations must be superior or equal to zero"
    else
        throw(ArgumentError("Downtime must be a positive number or a vector of positive numbers"))
    end
    @argcheck minratio <= startupratio <= 1. "startupratio must be between minratio and 1"
    @argcheck minratio <= shutdownratio <= 1. "shutdownratio must be between minratio and 1"
    UnitCommitment(pname, minratio, Float64(startup), Float64(shutdown), Float64(uptime), Float64.(downtime), Float64(startupratio), Float64(shutdownratio), integer)
end

# unitcommitment will branch into fleet commitment or single unit commitment depending on whether unitsize is defined @ capacity associated with port pname
abstract type AbstractUnitCommitmentBehavior{T} <: AbstractRegularBehavior{T} end

function buildbehavior(c::Component, b::UnitCommitment)
    cap = getcapacitybehavior(c, b.pname)
    if isnothing(cap) 
        throw(AssertionError("Component does not have capacity behavior associated with port $(b.pname)"))
    end
    if isnothing(_unitsize(cap))
        return SingleUnitCommitmentBehavior(c, b, cap)
    else
        return FleetUnitCommitmentBehavior(c, b, cap)
    end
end


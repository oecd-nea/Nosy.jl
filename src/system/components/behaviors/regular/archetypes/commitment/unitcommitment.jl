using JuMP: @variable, AffExpr
using ArgCheck: @argcheck

"""
Behavior: unit commitment for fleet of components.
"""

struct UnitCommitment <: AbstractBehaviorData
    pname::String
    minratio::Float64
    startup::Float64
    shutdown::Float64
    uptime::Float64
    downtime::Float64
    integer::Bool
end

"""
    UnitCommitment(pname::String, minratio::Number; startup::Int=0, shutdown::Int=0, uptime::Int=0, downtime::Int=0, integer::Bool=false)
Return a UnitCommitment behavior related to port `pname`, with minimum flow ratio `minratio`.
Optional parameters:
  * startup: startup duration in hours (default=0).
  * shutdown: shutdown duration in hours (default=0).
  * uptime:: minimum uptime duration in hours (default=0).
  * downtime: minimum downtime duration in hours (default=0).
  * integer: whether the unit commitment must follow an integer constraint (default=false).
"""
function UnitCommitment(pname::String, minratio::Number; startup::Number=0, shutdown::Number=0, uptime::Number=0, downtime::Number=0, integer::Bool=false)
    @argcheck 0 <= minratio <= 1. "minratio must be between 0 and 1."
    @argcheck startup >= 0 && shutdown >= 0 && uptime >= 0 && downtime >= 0 "All durations must be superior or equal to zero"
    UnitCommitment(pname, minratio, Float64(startup), Float64(shutdown), Float64(uptime), Float64(downtime), integer)
end

# unitcommitment will branch into fleet commitment or single unit commitment depending on whether unitsize is defined @ capacity associated with port pname
abstract type AbstractUnitCommitmentBehavior{T} <: AbstractRegularBehavior{T} end

function buildbehavior(c::Component, b::UnitCommitment)
    cap = getcapacitybehavior(c, b.pname)
    @assert !isnothing(cap) "Component does not have capacity behavior associated with port $(b.pname)"
    if isnothing(_unitsize(cap))
        return SingleUnitCommitmentBehavior(c, b, cap)
    else
        return FleetUnitCommitmentBehavior(c, b, cap)
    end
end


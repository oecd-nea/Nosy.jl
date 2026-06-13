"""
FleetUnitCommitmentFromIni

This behavior emulates a FleetUnitCommitment, with all the selector fields being exogenously defined.
It is used when one needs to re-run an optimisation with integer variables being fixed to optimal value (e.g. to evaluate duals of constraints).
This behavior is not exported.
"""

struct FleetUnitCommitmentFromIni <: AbstractUnitCommitmentData
    pname::String
    minratio::Float64

    startup::Float64
    shutdown::Float64
    uptime::Float64
    downtime::Vector{Float64}
    startupratio::Float64
    shutdownratio::Float64
    integer::Bool

    series_startup::Stepwise{Float64}
    series_shutdown::Stepwise{Float64}
    series_shutdown_selector::Vector{Stepwise{Float64}}
    series_state::Stepwise{Float64}
end

function FleetUnitCommitmentFromIni(ini::FleetUnitCommitmentBehavior{Float64})
    FleetUnitCommitmentFromIni(
        ini.data.pname,
        ini.data.minratio,
        
        ini.data.startup,
        ini.data.shutdown,
        ini.data.uptime,
        ini.data.downtime,
        ini.data.startupratio,
        ini.data.shutdownratio,
        ini.data.integer,

        ini.startup,
        ini.shutdown,
        ini.shutdownselector,
        ini.state,
    )
end

UnitCommitment(ini::FleetUnitCommitmentBehavior{Float64}) = FleetUnitCommitmentFromIni(ini)

struct FleetUnitCommitmentFromIniBehavior{T<:VAL,M<:Function} <: AbstractFleetUnitCommitmentBehavior{T}
    data::FleetUnitCommitmentFromIni
    
    # capacity data
    modifier::M
    unitsize::Float64

    # uc fixed variables (to mimic FleetUnitCommitment)
    startup::Stepwise{Float64}
    shutdown::Stepwise{Float64}
    shutdownselector::Vector{Stepwise{Float64}}
    state::Stepwise{Float64}

    # uc variables
    variable::Stepwise{T}
end

function buildbehavior(c::Component, b::FleetUnitCommitmentFromIni)
    for compcap in getbehaviors(c, AbstractComposedCapacityBehavior)
        if b.pname in _portname(compcap)
            throw(AssertionError("FleetUnitCommitmentFromIni is not compatible with composed capacities. Port $(b.pname) is covered by a composed capacity behavior."))
        end
    end

    cap = getcapacitybehavior(c, b.pname)
    if isnothing(cap) 
        throw(AssertionError("Component does not have capacity behavior associated with port $(b.pname)"))
    end
    if !(cap isa AbstractSingleCapacityBehavior)
        throw(AssertionError("FleetUnitCommitmentFromIni requires a single-port capacity behavior on port $(b.pname)."))
    end
    if isnothing(_unitsize(cap))
        throw(AssertionError("Not implemented"))
    else
        return FleetUnitCommitmentFromIniBehavior(c, b, cap)
    end
end

function FleetUnitCommitmentFromIniBehavior(c::Component, b::FleetUnitCommitmentFromIni, cap::AbstractCapacityBehavior)
    s = sim(c)
    m = mesh(c)
    
    umax = _nbunitsmax(cap) # max number of units
    
    if b.minratio == 1.
        vmax = 0. # remove ambiguity when minratio == 1 and umax == Inf
    else
        vmax = Float64(umax * _unitsize(cap) * (1 - b.minratio))  # max variable output
    end

    # if there is no variable part for the output, we don't generate a variable for it
    if iszero(vmax)
        variable = Stepwise(zeros(exptype(s), nsteps(m)), m) # warning: all elements link to same GenericAffExpr. This is on purpose, to reduce allocation.
    else
        variable = Stepwise(s, m, lb=0, ub=vmax, basename=name(c) * "_var")
    end
    
    return FleetUnitCommitmentFromIniBehavior(b, cap.data.modifier, _unitsize(cap), b.series_startup, b.series_shutdown, b.series_shutdown_selector, b.series_state, variable)
end

# constraints are defined by AbstractFleetUnitCommitmentBehavior

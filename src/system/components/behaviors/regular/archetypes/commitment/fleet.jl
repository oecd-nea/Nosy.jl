"""
Fleet unit commitment.

UC rules:
  * state = 0 when off, state = 1 when on. During startup and shutdown, state = 0.
  * startup = 1 at the moment the unit effectively ends start up process. state increments at the same step when startup is 1. startup is 0 otherwise.
  * shutdown = 1 at the moment the unit effectively begins shutting down process. state decrements at the step after shutdown is 1. shutdown is 0 otherwise.
"""


struct FleetUnitCommitmentBehavior{T<:VAL,M<:Function} <: AbstractUnitCommitmentBehavior{T}
    data::UnitCommitment
    
    # capacity data
    modifier::M
    unitsize::Float64

    # uc variables
    startup::Stepwise{T}
    shutdown::Stepwise{T}
    state::Stepwise{T}
    variable::Stepwise{T}
end

using Infiltrator

function FleetUnitCommitmentBehavior(c::Component, b::UnitCommitment, cap::AbstractCapacityBehavior)
    s = sim(c)
    
    umax = _nbunitsmax(cap) # max number of units
    vmax = umax * _unitsize(cap) * (1 - b.minratio)  # max variable output
    
    # uc variables
    # all are expressed in nb of units except variable
    startup = Stepwise(s, ub=umax, integer=b.integer, basename=name(c) * "_su")
    shutdown = Stepwise(s, ub=umax, integer=b.integer, basename=name(c) * "_sd")
    state = Stepwise(s, ub=umax, integer=b.integer, basename=name(c) * "_uc")
        
    # if there is no variable part for the output, we don't generate a variable for it
    if iszero(vmax)
        variable = Stepwise(zeros(AffExpr, nsteps(s)), s.mesh) # warning: all elements link to same AffExpr. This is on purpose, to reduce allocation.
    else
        variable = Stepwise(s, lb=0, ub=vmax, basename=name(c) * "_var") # deactivate ub=ub(vmax) because constraint is mandatory
    end

    return FleetUnitCommitmentBehavior(b, cap.data.modifier, _unitsize(cap), startup, shutdown, state, variable)
end

"""
Next functions quantify the different components of the UC flow:
  * _com: flow due to the fact that some units are committed -> min flow + variable flow
  * _su: flow due to the fact that some units are starting up
  * _sd: flow due to the fact that some units are shutting down
"""

function _com(b::FleetUnitCommitmentBehavior)
    return b.data.minratio * b.unitsize * b.state
end

function _var(b::FleetUnitCommitmentBehavior)
    return b.variable
end

# nb the durations are in hours, not in steps
# the time intervals can be arbitrarily small
function _lin_ratio_su(sud, timebeforesu)
    if 0 < timebeforesu < sud
        return Float64((sud - timebeforesu) / sud)
    else
        return 0.
    end
end

function _su(b::FleetUnitCommitmentBehavior{T}) where T
    m = b.startup.mesh # mesh
    _su = Stepwise(differentzerovector(T, nsteps(m)), m)
    for step in eachindex(_su)
        local deltah = 0//1
        local step2 = step - 1
        while deltah < b.data.startup        
            deltah += weight(m, step2)
            _su[step2] += b.startup[step] * b.unitsize * b.data.minratio * _lin_ratio_su(b.data.startup, deltah)
            step2 = step2 - 1
        end
    end
    return _su
end

# nb the durations are in hours, not in steps
# the time intervals can be arbitrarily small
function _lin_ratio_sd(sdd, timeaftersd)
    if 0 < timeaftersd < sdd
        return Float64((sdd - timeaftersd) / sdd)
    else
        return 0.
    end
end

function _sd(b::FleetUnitCommitmentBehavior{T}) where T
    m = b.startup.mesh # mesh
    _sd = Stepwise(differentzerovector(T, nsteps(m)), m)
    for step in eachindex(_sd)
        local deltah = 0//1
        local step2 = step + 1
        while deltah < b.data.startup        
            deltah += weight(m, step2)
            _sd[step2] += b.shutdown[step] * b.unitsize * b.data.minratio * _lin_ratio_sd(b.data.shutdown, deltah)
            step2 = step2 + 1
        end
    end
    return _sd
end

_flow(b::FleetUnitCommitmentBehavior) = _com(b) + _var(b) + _su(b) + _sd(b)


"""
Unit commitment constraints:
  * switch: next step in function of previous step and startup/shutdown
  * variable flow: variable flow is less than the maximum variable flow
  * units: number of units is less than the maximum number of units
  * min uptime: minimum uptime constraint
  * min downtime: minimum downtime constraint
  * flow: the flow of the port is equal to the flow calculated through unit commitment

NB the startup and shutdown duration are not constraints, they are used to compute the flow.
"""

function _apply_constraint_uc_switch!(c::Component, b::FleetUnitCommitmentBehavior)
    @constraint(sim(c).model,
        b.state.data .== (shift(b.state, -1) + b.startup - shift(b.shutdown, -1)).data
    )
end

# not applied if minratio is 0 (no variable part of flow)
function _apply_constraint_uc_variable_flow!(c::Component, b::FleetUnitCommitmentBehavior)
    if b.data.minratio > 0
        @constraint(sim(c).model, 
            b.variable.data .<= ((b.unitsize * (1. - b.data.minratio)) * b.state).data
        )
    end
end

# the constraint below is redundant
# it may guide the solver, but is not mandatory (already included in the uc flow constraint)
function _apply_constraints_uc_units!(c::Component, b::FleetUnitCommitmentBehavior)
    nothing
    # @constraint(sim(c).model, 
    #     b.state.data .<= nbunits(c)
    # )
end

function _apply_constraints_uc_minuptime!(c::Component, b::FleetUnitCommitmentBehavior)
    if b.data.uptime > 0
        m = sim(c).mesh
        for step in eachindex(b.state)
            val = AffExpr(0.)
            local deltah = 0//1
            local step2 = step - 1
            while deltah < b.data.uptime        
                val += b.startup[step2]
                deltah += weight(m, step2)
                step2 = step2 - 1
            end
            @constraint(sim(c).model, val <= b.state[step])
        end
    end
end

function _apply_constraints_uc_mindowntime!(c::Component, b::FleetUnitCommitmentBehavior)
    if b.data.downtime > 0
        m = sim(c).mesh
        _units = nbunits(c)
        for step in eachindex(b.state)
            val = AffExpr(0.)
            local deltah = 0//1
            local step2 = step - 1
            while deltah <= b.data.downtime + b.data.startup
                val += b.shutdown[step2]  
                deltah += weight(m, step2)
                step2 = step2 - 1
            end
            @constraint(sim(c).model, val <= _units - b.state[step])
        end
    end
end

function _apply_constraints_uc_flow!(c::Component, b::FleetUnitCommitmentBehavior)
    @constraint(sim(c).model, 
        b.modifier(getport(c, b.data.pname)).data .== _flow(b).data
    )
end


function _apply_constraints!(c::Component, b::FleetUnitCommitmentBehavior)
    _apply_constraint_uc_switch!(c, b)
    _apply_constraint_uc_variable_flow!(c, b)
    # _apply_constraints_uc_units!(c, b)
    _apply_constraints_uc_minuptime!(c, b)
    _apply_constraints_uc_mindowntime!(c, b)
    _apply_constraints_uc_flow!(c, b)
end

behaviorname(::FleetUnitCommitmentBehavior) = "Fleet unit commitment"

# display behavior info
function Base.show(io::IO, b::FleetUnitCommitmentBehavior)
  print(
      io, 
      "Behavior \"$(behaviorname(b))\""
  )
end
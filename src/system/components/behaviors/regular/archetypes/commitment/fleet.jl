"""
Fleet unit commitment.

UC rules:
  * state = 0 when off, state = 1 when on. During startup and shutdown, state = 0.
  * startup = 1 at the moment the unit effectively ends start up process. state increments at the same step when startup is 1. startup is 0 otherwise.
  * shutdown = 1 at the moment the unit effectively begins shutting down process. state decrements at the step after shutdown is 1. shutdown is 0 otherwise.
"""

"""
Warning
The UC switch variables (startup, shutdown) are not designed to be converted to Hourly, because they do not represent flows but switches.
For instance, some startups will not appear if the series is converted to Hourly.
Therefore, special care must be applied when manipulating these series. For instance: see StartupCost behavior.
However, the UC flows (including evaluated with _su and _sd functions) can be converted to Hourly and integrated.
"""

abstract type AbstractFleetUnitCommitmentBehavior{T} <: AbstractUnitCommitmentBehavior{T} end

struct FleetUnitCommitmentBehavior{T<:VAL,M<:Function} <: AbstractFleetUnitCommitmentBehavior{T}
    data::UnitCommitment
    
    # capacity data
    modifier::M
    unitsize::Float64

    # uc variables
    startup::Stepwise{T}
    shutdown::Stepwise{T}
    shutdownselector::Vector{Stepwise{T}}
    state::Stepwise{T}
    variable::Stepwise{T}
end

function FleetUnitCommitmentBehavior(c::Component{T}, b::UnitCommitment, cap::AbstractCapacityBehavior) where T
    s = sim(c)
    
    umax = _nbunitsmax(cap) # max number of units
    
    if b.minratio == 1.
        vmax = 0. # remove ambiguity when minratio == 1 and umax == Inf
    else
        vmax = Float64(umax * _unitsize(cap) * (1 - b.minratio))  # max variable output
    end
    
    # check inconsistency between capacity and number of units
    # not only such cases are inconsistency,
    # but they tend to be difficult to optimize
    if cap isa FixedCapacityBehavior && b.integer
        @argcheck isinteger(umax) "Cannot define integer UC together with non-integer number of units from fixed capacity. Please use a multiple of $(_unitsize(cap))"
    end

    # uc variables
    # all are expressed in nb of units except variable
    # NB startup xor shutdown can in theory not be integer even if b.integer
    # however solver performance test showed that it's better to set all as b.integer
    startup = Stepwise(s, ub=umax, integer=b.integer, basename=name(c) * "_su")
    shutdown = Stepwise(s, ub=umax, integer=b.integer, basename=name(c) * "_sd")
    state = Stepwise(s, ub=umax, integer=b.integer, basename=name(c) * "_uc")

    # shutdown selector variable
    if length(b.downtime) == 1
        
        #if there is only one way to shutdown
        shutdownselector = [shutdown]

    else
        
        # if there are multiple ways to shutdown

        # set shutdown to not integer (already taken into account by selectors)
        for e in shutdown
            v = first(e.terms)[1]
            is_integer(v) && unset_integer(v)
        end

        # generate variables for shutdown selector
        shutdownselector = Vector{Stepwise{T}}(undef,length(b.downtime))
        for i in eachindex(b.downtime)
            shutdownselector[i] = Stepwise(s, ub=umax, integer=b.integer, basename=name(c) * "_sds" * string(i))
        end

    end
        
    # if there is no variable part for the output, we don't generate a variable for it
    if iszero(vmax)
        variable = Stepwise(zeros(exptype(s), nsteps(s)), s.mesh) # warning: all elements link to same GenericAffExpr. This is on purpose, to reduce allocation.
    else
        variable = Stepwise(s, lb=0, ub=vmax, basename=name(c) * "_var") # deactivate ub=ub(vmax) because constraint is mandatory
    end

    return FleetUnitCommitmentBehavior(b, cap.data.modifier, _unitsize(cap), startup, shutdown, shutdownselector, state, variable)
end

"""
Next functions quantify the different components of the UC flow:
  * _com: flow due to the fact that some units are committed -> min flow + variable flow
  * _su: flow due to the fact that some units are starting up
  * _sd: flow due to the fact that some units are shutting down
"""

function _com(b::AbstractFleetUnitCommitmentBehavior)
    return b.data.minratio * b.unitsize * b.state
end

function _var(b::AbstractFleetUnitCommitmentBehavior)
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

function _su(b::AbstractFleetUnitCommitmentBehavior{T}) where T
    m = b.startup.mesh # mesh
    _su = Stepwise(differentzerovector(T, nsteps(m)), m)
    for step in eachindex(_su)
        local deltah = 0//1
        local step2 = step - 1
        while deltah < b.data.startup        
            deltah += weight(m, step2)
            _su[step2] += b.startup[step] * b.unitsize * b.data.startupratio * _lin_ratio_su(b.data.startup, deltah)
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

function _sd(b::AbstractFleetUnitCommitmentBehavior{T}) where T
    m = b.startup.mesh # mesh
    _sd = Stepwise(differentzerovector(T, nsteps(m)), m)
    for step in eachindex(_sd)
        local deltah = 0//1
        local step2 = step + 1
        while deltah < b.data.shutdown     
            deltah += weight(m, step2)
            _sd[step2] += b.shutdown[step] * b.unitsize * b.data.shutdownratio * _lin_ratio_sd(b.data.shutdown, deltah)
            step2 = step2 + 1
        end
    end
    return _sd
end

_flow(b::AbstractFleetUnitCommitmentBehavior) = _com(b) + _var(b) + _su(b) + _sd(b)


# return the "up" state, which is either unit is committed, or is in startup or shutdown process
# in other words, if and only if the unit is doing something, the "up" state is positive.
function _up(b::AbstractFleetUnitCommitmentBehavior{T}) where T
    m = b.startup.mesh

    _up = Stepwise(differentzerovector(T, nsteps(m)), m)
    for step in eachindex(_up)

        # number of units committed
        _val = b.state[step]
        
        # number of units in shutdown procedure
        local deltah = weight(m, step)
        local step2 = step - 1
        while deltah < b.data.shutdown
            deltah += weight(m, step2)
            _val += b.shutdown[step2]
            step2 = step2 - 1
        end

        # number of units in startup procedure
        local deltah = weight(m, step)
        local step2 = step + 1
        while deltah < b.data.startup
            deltah += weight(m, step2)
            _val += b.startup[step2]
            step2 = step2 + 1
        end

        _up[step] = _val
    end

    return _up
end


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

function _apply_constraint_uc_switch!(c::Component, b::AbstractFleetUnitCommitmentBehavior)
    @constraint(lowermodel(sim(c)),
        b.state.data .== (shift(b.state, -1) + b.startup - shift(b.shutdown, -1)).data
    )
end

# not applied if minratio is 1 (no variable part of flow)
function _apply_constraint_uc_variable_flow!(c::Component, b::AbstractFleetUnitCommitmentBehavior)
    if b.data.minratio < 1
        @constraint(lowermodel(sim(c)), 
            (b.variable -  b.state * (b.unitsize * (1. - b.data.minratio))).data .<= 0.
        )
    end
end

# the constraint below is redundant
# it may guide the solver, but is not mandatory (already included in the uc flow constraint)
# function _apply_constraints_uc_units!(c::Component, b::FleetUnitCommitmentBehavior)
#     @constraint(lowermodel(sim(c)), 
#         b.state.data .<= nbunits(c)
#     )
# end

function _apply_constraints_uc_minuptime!(c::Component, b::AbstractFleetUnitCommitmentBehavior)
    m = sim(c).mesh

    lm = lowermodel(sim(c)) # type unstable, don't access it in loop

    for step in eachindex(b.state)
        val = exptype(sim(c))(0.)
        local deltah = 0//1
        local step2 = step - 1
        while deltah < b.data.uptime
            addto!(val, b.startup[step2])
            deltah += weight(m, step2)
            step2 = step2 - 1
        end
        if !iszero(val)
            @constraint(lm, val <= b.state[step])
        end
    end
end

# the constraint below is tricky
# first, the downtime actually covers the time of shutdown and startup: their uc state is 0 but their flow is not, by convention.
# Then startup duration can be 0. But even when it is zero, startup at least takes a step to transition between state=0 to state=1!
# Same remark for shutdown.
# The implementation of the constraint is tested for constant time intervals, it will not be correct for variable time intervals.
# TODO update the implementation to handle variable time intervals
function _apply_constraints_uc_mindowntime!(c::Component, b::AbstractFleetUnitCommitmentBehavior)
    m = sim(c).mesh
    _units = nbunits(c)

    lm = lowermodel(sim(c)) # type unstable, don't access it in loop

    # outer loop on shutdown types
    
    for step in eachindex(b.state)
        val = exptype(sim(c))(0.)
        for sdtype in eachindex(b.shutdownselector)
            local step2 = step - 1
            local deltah = 0//1
            while deltah < b.data.downtime[sdtype] + max(b.data.shutdown,weight(m,step-1)) + max(b.data.startup,weight(m,step-1)) # TODO reevaluate duration of interval, use a while condition on state function instead of counting hours
                addto!(val, b.shutdownselector[sdtype][step2])  
                deltah += weight(m, step2)
                step2 = step2 - 1
            end
        end
        if !iszero(val)
            @constraint(lm, val <= _units - b.state[step] + b.startup[step])
        end
    end
end

function _apply_constraints_uc_shutdownselector!(c::Component, b::AbstractFleetUnitCommitmentBehavior)
    # this constraint is only meaningful if there are multiple shutdown selectors
    if length(b.shutdownselector) > 1
        @constraint(lowermodel(sim(c)), 
            sum(b.shutdownselector).data .== b.shutdown.data
        )
    end
end

function _apply_constraints_uc_flow!(c::Component, b::AbstractFleetUnitCommitmentBehavior)
    @constraint(lowermodel(sim(c)), 
        b.modifier(getport(c, b.data.pname)).data .== _flow(b).data
    )
end


function _apply_constraint_su_sd(c::Component, b::AbstractFleetUnitCommitmentBehavior)
    # cannot shutdown more units than committed
    @constraint(lowermodel(sim(c)),
        b.shutdown.data .<= b.state.data
    )

    # cannot startup more units than not committed
    # this constraint is not mandatory, but it might guide the solver
    # @constraint(lowermodel(sim(c)),
    #     b.startup.data .<= nbunits(c) .- shift(b.state, -1)
    # )
end

function _apply_constraints!(c::Component, b::AbstractFleetUnitCommitmentBehavior)
    _apply_constraint_uc_switch!(c, b)
    _apply_constraint_uc_variable_flow!(c, b)
    # _apply_constraints_uc_units!(c, b)
    _apply_constraints_uc_minuptime!(c, b)
    _apply_constraints_uc_mindowntime!(c, b)
    _apply_constraints_uc_shutdownselector!(c,b)
    _apply_constraints_uc_flow!(c, b)
    _apply_constraint_su_sd(c, b)
end

portname(uc::AbstractFleetUnitCommitmentBehavior) = uc.data.pname


behaviorname(::AbstractFleetUnitCommitmentBehavior) = "Fleet unit commitment"

# display behavior info
function Base.show(io::IO, b::AbstractFleetUnitCommitmentBehavior)
  print(
      io, 
      "Behavior \"$(behaviorname(b))\""
  )
end
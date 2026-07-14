"""
Fleet unit commitment.

UC rules:
  * state = 0 when off, state = 1 when on. During startup and shutdown, state = 0.
  * startup = 1 at the moment the unit effectively ends start up process. state increments at the same step when startup is 1. startup is 0 otherwise.
  * shutdown = 1 at the moment the unit effectively begins shutting down process. state decrements at the step after shutdown is 1. shutdown is 0 otherwise.
"""

"""
Warning for developers:
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

    # UC variables and expressions
    startup::Stepwise{T}
    shutdown::Stepwise{T}
    shutdownselector::Vector{Stepwise{T}}
    state::Stepwise{T}
    variable::Stepwise{T}
end

function FleetUnitCommitmentBehavior(c::Component{T}, b::UnitCommitment, cap::AbstractCapacityBehavior) where T
    s = sim(c)
    m = mesh(c)
    modifier = cap.data.modifier
    unitsize = _unitsize(cap)

    umax = _nbunitsmax(cap) # max number of units
    # check inconsistency between capacity and number of units
    # not only such cases are inconsistency,
    # but they tend to be difficult to optimize
    if cap isa FixedCapacityBehavior && b.integer
        @argcheck isinteger(umax) "Cannot define integer UC together with non-integer number of units from fixed capacity. Please use a multiple of $(_unitsize(cap))"
    end

    # uc variables
    # all are expressed in nb of units except variable


    # generate stepwise vector from startup mask
    if isnothing(b.startupmask)
        stm = Stepwise(fill(true, nsteps(m)), m)
    else
        stm = Stepwise(b.startupmask, m)
    end

    # generate variables for startup
    startup = Stepwise(s, m, ub=umax, integer=b.integer, basename=name(c) * "_su", mask=stm)


    # generate stepwise vectors from shutdown mask
    if isnothing(b.shutdownmask)
        sdm = [Stepwise(fill(true, nsteps(m)), m) for _ in eachindex(b.downtime)]
    else
        sdm = Vector{Stepwise{Bool}}(undef,0)
        for v in b.shutdownmask
            push!(sdm, Stepwise(v, m))
        end
    end
    
    # generate variables for shutdown selector
    shutdownselector = Vector{Stepwise{T}}(undef,length(b.downtime))
    for i in eachindex(b.downtime)
        shutdownselector[i] = Stepwise(s, m, ub=umax, integer=b.integer, basename=name(c) * "_sds" * string(i), mask=sdm[i]) # integer shutdown
    end
    # Keep aggregate shutdown as an expression so no additional variable or
    # selector-linking equality is needed.
    shutdown = sum(shutdownselector)


    # state variable
    # we apply a state propagation algorithm
    # if startup mask and shutdown mask are false often enough, we can simplify state by extending previous state

    # sum of shifted masks
    eventmask = .!iszero.(stm + shift(sum(sdm), -1))
    
    if !any(eventmask)
        eventmask[1] = true # we at least need one UC state variable (always on / always off)
    end
    state = Stepwise(s, m, ub=umax, integer=b.integer, basename=name(c) * "_uc", mask=eventmask)

    # look for first true mask index
    # we will loop starting here
    nz = findfirst(eventmask)
    for i in (nz+1):(nz+nsteps(m)-1) # we can loop on a stepwise, no bounds problem
        if iszero(state[i])
            state[i] = state[i-1] # reference to previous state
        end
    end

    # Reuse the port dispatch instead of introducing a second continuous
    # variable and an equality linking it to the UC flow decomposition.
    variable = _variable_dispatch(c, b, modifier, unitsize, startup, shutdown, state)

    return FleetUnitCommitmentBehavior(
        b,
        modifier,
        unitsize,
        startup,
        shutdown,
        shutdownselector,
        state,
        variable,
    )
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

function _su(data::AbstractUnitCommitmentData, unitsize::Float64, startup::Stepwise{T}) where T
    m = startup.mesh
    _su = Stepwise(differentzerovector(T, nsteps(m)), m)
    for step in eachindex(_su)
        local deltah = 0//1
        local step2 = step - 1
        while deltah < data.startup
            deltah += weight(m, step2)
            ratio = _lin_ratio_su(data.startup, deltah)
            _su[step2] += startup[step] * unitsize * data.startupratio * ratio
            step2 = step2 - 1
        end
    end
    return _su
end

_su(b::AbstractFleetUnitCommitmentBehavior) = _su(b.data, b.unitsize, b.startup)

# nb the durations are in hours, not in steps
# the time intervals can be arbitrarily small
function _lin_ratio_sd(sdd, timeaftersd)
    if 0 < timeaftersd < sdd
        return Float64((sdd - timeaftersd) / sdd)
    else
        return 0.
    end
end

function _sd(data::AbstractUnitCommitmentData, unitsize::Float64, shutdown::Stepwise{T}) where T
    m = shutdown.mesh
    _sd = Stepwise(differentzerovector(T, nsteps(m)), m)
    for step in eachindex(_sd)
        local deltah = 0//1
        local step2 = step + 1
        while deltah < data.shutdown
            deltah += weight(m, step2)
            ratio = _lin_ratio_sd(data.shutdown, deltah)
            _sd[step2] += shutdown[step] * unitsize * data.shutdownratio * ratio
            step2 = step2 + 1
        end
    end
    return _sd
end

_sd(b::AbstractFleetUnitCommitmentBehavior) = _sd(b.data, b.unitsize, b.shutdown)

function _variable_dispatch(c::Component, data::AbstractUnitCommitmentData, modifier::Function,
    unitsize::Float64, startup::Stepwise, shutdown::Stepwise, state::Stepwise)
    flow = modifier(getport(c, data.pname))
    committed = data.minratio * unitsize * state
    return flow - committed - _su(data, unitsize, startup) - _sd(data, unitsize, shutdown)
end

_flow(b::AbstractFleetUnitCommitmentBehavior) = _com(b) + _var(b) + _su(b) + _sd(b)


# return the "up" state, which is either unit is committed, or is in startup or shutdown process
# in other words, if and only if the unit is doing something, the "up" state is positive.
function _up(b::AbstractFleetUnitCommitmentBehavior{T}) where T
    m = b.startup.mesh
    _up = Stepwise(differentzerovector(T, nsteps(m)), m)

    for step in eachindex(_up)
        _val = b.state[step]

        local passed = 0//1
        local step2 = step - 1
        while passed + weight(m, step2) < b.data.shutdown
            _val += b.shutdown[step2]
            passed += weight(m, step2)
            step2 -= 1
        end

        local passed2 = 0//1
        local step3 = step + 1
        while passed2 + weight(m, step3) < b.data.startup
            _val += b.startup[step3]
            passed2 += weight(m, step3)
            step3 += 1
        end

        _up[step] = _val
    end

    return _up
end


"""
Unit commitment constraints:
  * switch: next step in function of previous step and startup/shutdown
  * variable flow: residual dispatch is between zero and its endpoint-aware maximum
  * units: number of units is less than the maximum number of units
  * min uptime: minimum uptime constraint
  * min downtime: minimum downtime constraint

NB the startup and shutdown duration are not constraints, they are used to compute the flow.
"""

function _apply_constraint_uc_switch!(c::Component, b::AbstractFleetUnitCommitmentBehavior)
    lm = lowermodel(sim(c))
    next_state = shift(b.state, -1) + b.startup - shift(b.shutdown, -1)
    for step in eachindex(b.state)
        if !iszero(b.state[step] - next_state[step])
            @constraint(lm, b.state[step] == next_state[step])
        end
    end
end

# At minratio equal to one, the residual dispatch is fixed to zero. Otherwise,
# it can span the range between minimum and maximum output for a regular
# committed unit. Units completing startup or beginning shutdown are instead
# capped by their respective endpoint ratios. Startup and shutdown cuts are
# kept separate because the same unit may complete startup and begin shutdown
# in one timestep. A regular bound is added only where neither cut is active,
# avoiding redundant rows when event variables are masked out.
function _apply_constraint_uc_variable_flow!(c::Component, b::AbstractFleetUnitCommitmentBehavior)
    lm = lowermodel(sim(c))
    if b.data.minratio == 1.
        for variable_dispatch in b.variable
            if !iszero(variable_dispatch)
                @constraint(lm, variable_dispatch == 0.)
            end
        end
    else
        max_variable_flow = b.state * (b.unitsize * (1. - b.data.minratio))
        for step in eachindex(b.variable)
            if !iszero(b.variable[step])
                @constraint(lm, b.variable[step] >= 0.)
            end

            base_margin = b.variable[step] - max_variable_flow[step]
            has_endpoint_cut = false

            if b.data.startupratio < 1. && !iszero(b.startup[step])
                startup_margin = base_margin + b.startup[step] * b.unitsize * (1. - b.data.startupratio)
                @constraint(lm, startup_margin <= 0.)
                has_endpoint_cut = true
            end

            if b.data.shutdownratio < 1. && !iszero(b.shutdown[step])
                shutdown_margin = base_margin + b.shutdown[step] * b.unitsize * (1. - b.data.shutdownratio)
                @constraint(lm, shutdown_margin <= 0.)
                has_endpoint_cut = true
            end

            if !has_endpoint_cut && !iszero(base_margin)
                @constraint(lm, base_margin <= 0.)
            end
        end
    end
end

# Fixed-capacity commitment states already have the installed number of units as
# their variable upper bound. For investable capacity, the variable upper bound
# is only the maximum build, so an explicit coupling to the actual build is
# required. In particular, this constraint must not depend on the presence of
# shutdown variables: masks can otherwise remove the indirect coupling from the
# minimum-downtime constraints.
function _apply_constraint_uc_units!(c::Component, b::AbstractFleetUnitCommitmentBehavior)
    cap = getcapacitybehavior(c, b.data.pname)
    if cap isa VariableCapacityBehavior
        units = _nbunits(cap)
        lm = lowermodel(sim(c))
        for step in eachindex(b.state)
            @constraint(lm, b.state[step] <= units)
        end
    end
end

function _apply_constraints_uc_minuptime!(c::Component, b::AbstractFleetUnitCommitmentBehavior)
    m = mesh(c)

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
function _apply_constraints_uc_mindowntime!(c::Component, b::AbstractFleetUnitCommitmentBehavior)
    m = mesh(c)
    cap = getcapacitybehavior(c, b.data.pname)
    _units = _nbunits(cap)
    lm = lowermodel(sim(c)) 
    for step in eachindex(b.state)
        val = exptype(sim(c))(0.)
        for sdtype in eachindex(b.shutdownselector)
            local step2 = step - 1
            local passed = 0//1
            minstep = weight(m, step2)
            limit = b.data.downtime[sdtype] + max(b.data.shutdown, minstep) + max(b.data.startup, minstep)
            while passed < limit
                passed += weight(m, step2)
                addto!(val, b.shutdownselector[sdtype][step2])
                step2 = step2 - 1
            end
        end

        if !iszero(val)
            @constraint(lm, val <= _units - b.state[step] + b.startup[step])
        end
    end
end


function _apply_constraint_su_sd(c::Component, b::AbstractFleetUnitCommitmentBehavior)
    # cannot shutdown more units than committed
    lm = lowermodel(sim(c))
    for step in eachindex(b.shutdown)
        if !iszero(b.shutdown[step])
            shutdown_margin = b.shutdown[step] - b.state[step]
            if !iszero(shutdown_margin)
                @constraint(lm, shutdown_margin <= 0.)
            end
        end
    end
end

function _apply_constraints!(c::Component, b::AbstractFleetUnitCommitmentBehavior)
    _apply_constraint_uc_switch!(c, b)
    _apply_constraint_uc_variable_flow!(c, b)
    _apply_constraint_uc_units!(c, b)
    _apply_constraints_uc_minuptime!(c, b)
    _apply_constraints_uc_mindowntime!(c, b)
    _apply_constraint_su_sd(c, b)
end

portname(uc::AbstractFleetUnitCommitmentBehavior) = uc.data.pname

_state(uc::AbstractFleetUnitCommitmentBehavior) = uc.state

behaviorname(::AbstractFleetUnitCommitmentBehavior) = "Fleet unit commitment"

# display behavior info
function Base.show(io::IO, b::AbstractFleetUnitCommitmentBehavior)
  print(
      io, 
      "Behavior \"$(behaviorname(b))\""
  )
end

# helper function for other behaviors to get unit commitment behavior
# returns AbstractUnitCommitmentBehavior if found, nothing otherwise
function getunitcommitmentbehavior(c::Component, pname::String)
    for uc in getbehaviors(c, AbstractUnitCommitmentBehavior)
        if uc.data.pname == pname
            return uc
        end
    end
    return nothing
end

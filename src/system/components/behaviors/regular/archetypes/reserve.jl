"""
ReserveUp and ReserveDown behaviors.
ReserveUp provides upward reserve capacity through discharge increase or charge reduction.
ReserveDown provides downward reserve through discharge reduction or charge increase.
"""

"""
Reserve constraints.
Reserve capacity r (one value per timestep) is constrained in three groups.

Capacity/headroom
At each step r is limited by available headroom.
For sense :up, headroom is (capacity − flow); for :down, headroom is flow.
Without UC, flow is the port flow with the behavior's modifier.
With Fleet UC we split into r_online and r_fast: r_online is bounded by state-based headroom (_com + _var) and by unitsize * state (so zero during startup/shutdown when state=0).
For :up, r_fast is bounded by off-unit capacity (unitsize * startupratio per off unit) when startup duration <= dt[t]; for :down, r_fast is bounded by on-units not in shutdown, (state − shutdown) * unitsize * shutdownratio, when shutdown duration <=dt[t].
Units in shutdown are excluded so as not to overlap with the dispatch trajectory.
Total r = r_online + r_fast.

Ramping
The change in flow from one step to the next plus the reserve deployment must respect the ramping limit on the same port and sense.
Without UC, flow difference uses the port flow; with UC, only variable flow can move for reserve and max ramp is scaled by committed units (_state).
Only r_online is subject to ramping; r_fast is within-step delivery (fast start/down), so it is not limited by inter-step ramping.

Storage
For sense :up only, on storage models r is also limited by energy in store—on an output port by (efficiency * level / duration), on an input port by ((capacity − level) / (efficiency * duration)).
"""

using ArgCheck: @argcheck
using JuMP: @constraint

# Abstract type for reserve behavior data
abstract type AbstractReserveData <: AbstractBehaviorData end

# Abstract type for reserve behaviors
abstract type AbstractReserveBehavior{T} <: AbstractRegularBehavior{T} end

"""
    ReserveUp(name::String, pname::String, sense::Symbol, duration::Number; modifier::Function=defaultmodifier)

Return `ReserveUp` behavior data.

  * `name`: groups reserves at snapshot level (e.g., `"FCR"`, `"15min"`).
  * `pname`: port name the reserve applies to (e.g., `"output"`, `"input"`).
  * `sense`: `:up` (discharge increase) or `:down` (charge reduction); both provide upward reserve.
  * `duration`: duration in hours, used for energy-limited constraints.
  * `modifier`: must match the modifier used by capacity, ramping, and unit commitment behaviors for the target port.
"""
struct ReserveUp{M} <: AbstractReserveData
    name::String
    pname::String
    sense::Symbol
    duration::Float64
    modifier::M

    function ReserveUp(name::String, pname::String, sense::Symbol, duration::Number, modifier::Function)
        @argcheck (sense == :up || sense == :down) "ReserveUp: sense must be :up or :down"
        d = Float64(duration)
        @argcheck d > 0.0 "ReserveUp: duration must be positive"
        new{typeof(modifier)}(name, pname, sense, d, modifier)
    end
end

function ReserveUp(name::String, pname::String, sense::Symbol, duration::Number; modifier::Function=defaultmodifier)
    return ReserveUp(name, pname, sense, duration, modifier)
end

"""
    ReserveDown(name::String, pname::String, sense::Symbol, duration::Number; modifier::Function=defaultmodifier)

Return `ReserveDown` behavior data.

  * `name`: groups reserves at snapshot level (e.g., `"FCR"`, `"15min"`).
  * `pname`: port name the reserve applies to (e.g., `"output"`, `"input"`).
  * `sense`: `:down` (discharge reduction) or `:up` (charge increase); both provide downward reserve.
  * `duration`: duration in hours, used for energy-limited constraints.
  * `modifier`: must match the modifier used by capacity, ramping, and unit commitment behaviors for the target port.
"""
struct ReserveDown{M} <: AbstractReserveData
    name::String
    pname::String
    sense::Symbol
    duration::Float64
    modifier::M

    function ReserveDown(name::String, pname::String, sense::Symbol, duration::Number, modifier::Function)
        @argcheck (sense == :up || sense == :down) "ReserveDown: sense must be :up or :down"
        d = Float64(duration)
        @argcheck d > 0.0 "ReserveDown: duration must be positive"
        new{typeof(modifier)}(name, pname, sense, d, modifier)
    end
end

function ReserveDown(name::String, pname::String, sense::Symbol, duration::Number; modifier::Function=defaultmodifier)
    return ReserveDown(name, pname, sense, duration, modifier)
end

# One behavior type; constraints branch on data.sense and port (hasinput/hasoutput).
# rsense = reserve sense (:up/:down), for metrics and duplicate check per port.
# With Fleet UC: r_online (state based, 0 during transition) and r_fast (fast start/down) so we can
# constrain them separately (different time scales). r = r_online + r_fast. When no UC, r only.
struct ReserveBehavior{T,D<:AbstractReserveData} <: AbstractReserveBehavior{T}
    data::D
    r::Stepwise{T}
    rsense::Symbol
    r_online::Union{Stepwise{T},Nothing}
    r_fast::Union{Stepwise{T},Nothing}

    function ReserveBehavior{T,D}(data::D, r::Stepwise{T}, rsense::Symbol, r_online::Union{Stepwise{T},Nothing}, r_fast::Union{Stepwise{T},Nothing}) where {T,D<:AbstractReserveData}
        @argcheck (rsense == :up || rsense == :down) "ReserveBehavior: rsense must be :up or :down"
        new{T,D}(data, r, rsense, r_online, r_fast)
    end
end
# Infer T,D from args so callers need not pass type params.
function ReserveBehavior(data::D, r::Stepwise{T}, rsense::Symbol, r_online::Union{Stepwise{T},Nothing}=nothing, r_fast::Union{Stepwise{T},Nothing}=nothing) where {T,D<:AbstractReserveData}
    ReserveBehavior{T,D}(data, r, rsense, r_online, r_fast)
end

behaviorname(b::ReserveBehavior) = b.rsense == :up ? "reserve up" : "reserve down"

const RESERVE_COMPATIBLE_MODELS = (
    DispatchableSourceModel,
    BasicStorageModel,
    LazyStorageModel,
    BasicConverterModel,
)

function buildbehavior(c::Component, data::ReserveUp)
    @argcheck hasport(c, data.pname) "component '$(name(c))' does not have port '$(data.pname)'"
    if !any(model(c) isa T for T in RESERVE_COMPATIBLE_MODELS)
        throw(ArgumentError("Reserve not compatible with $(typeof(model(c))): $(name(c))"))
    end
    if any(b.rsense == :up && b.data.pname == data.pname for b in getbehaviors(c, ReserveBehavior))
        throw(ArgumentError("Component '$(name(c))' already has an upward reserve on port '$(data.pname)'. Only one per port is allowed."))
    end
    uc = getunitcommitmentbehavior(c, data.pname)
    return _build_reserve_behavior_impl(c, data, uc, :up)
end

function buildbehavior(c::Component, data::ReserveDown)
    @argcheck hasport(c, data.pname) "component '$(name(c))' does not have port '$(data.pname)'"
    if !any(model(c) isa T for T in RESERVE_COMPATIBLE_MODELS)
        throw(ArgumentError("Reserve not compatible with $(typeof(model(c))): $(name(c))"))
    end
    if any(b.rsense == :down && b.data.pname == data.pname for b in getbehaviors(c, ReserveBehavior))
        throw(ArgumentError("Component '$(name(c))' already has a downward reserve on port '$(data.pname)'. Only one per port is allowed."))
    end
    uc = getunitcommitmentbehavior(c, data.pname)
    return _build_reserve_behavior_impl(c, data, uc, :down)
end

# Non-UC case: create only r variable
function _build_reserve_behavior_impl(c::Component, data::Union{ReserveUp, ReserveDown}, uc::Nothing, sense::Symbol)
    base = name(c) * (sense == :up ? "_rup_" : "_rdn_") * string(data.name) * "_" * data.pname
    r = Stepwise(sim(c), mesh(c), lb=0, basename=base)
    return ReserveBehavior(data, r, sense, nothing, nothing)
end

# UC case (Fleet only): create r, r_online, r_fast variables
function _build_reserve_behavior_impl(c::Component, data::Union{ReserveUp, ReserveDown}, uc::AbstractFleetUnitCommitmentBehavior, sense::Symbol)
    base = name(c) * (sense == :up ? "_rup_" : "_rdn_") * string(data.name) * "_" * data.pname
    r = Stepwise(sim(c), mesh(c), lb=0, basename=base)
    r_online = Stepwise(sim(c), mesh(c), lb=0, basename=base * "_ronline")
    r_fast = Stepwise(sim(c), mesh(c), lb=0, basename=base * "_rfast")
    return ReserveBehavior(data, r, sense, r_online, r_fast)
end

function _apply_constraints!(c::Component, b::AbstractReserveBehavior)
    _apply_constraints_reserve_capacity!(c, b)
    _apply_constraints_reserve_ramping!(c, b)
    _apply_constraints_reserve_storage!(c, b)
end

# headroom: r limited by (capacity − flow) for :up, by flow for :down; UC uses committed flow.
function _apply_constraints_reserve_capacity!(c::Component{T}, b::AbstractReserveBehavior{T}) where T
    cap_behavior = getcapacitybehavior(c, b.data.pname)
    car = carrier(getport(c, b.data.pname))
    def = _defaultmodifier(carrierstyle(car))
    mod_cap = _modifier(cap_behavior)
    mod_b = b.data.modifier
    @argcheck (mod_cap === mod_b || (mod_cap === defaultmodifier && mod_b === def) || (mod_b === defaultmodifier && mod_cap === def)) "$(behaviorname(b)) modifier must match capacity modifier for port '$(b.data.pname)'"
    uc = getunitcommitmentbehavior(c, b.data.pname)
    __apply_constraints_reserve_capacity!(c, b, uc)
end
# non-UC: headroom at t from flow[t] (reserve is availability now, not deployment later). :up -> cap − flow, :down -> flow.
function __apply_constraints_reserve_capacity!(c::Component{T}, b::AbstractReserveBehavior{T}, uc::Nothing) where T
    m = lowermodel(sim(c))
    flow = b.data.modifier(getport(c, b.data.pname))
    if b.data.sense == :up
        cap = capacity(c, b.data.pname; multiplier=true)
        if cap isa Stepwise
            cap_data = cap.data
        else
            cap_data = _to_affexpr(cap, m)
        end
        @constraint(m, b.r.data .<= (cap_data .- flow.data))
    else
        @constraint(m, b.r.data .<= flow.data)
    end
end
# UC (Fleet): r_online from on-units headroom (0 during transition); r_fast from off-units when _d <= timestep (fast start).
function __apply_constraints_reserve_capacity!(c::Component{T}, b::AbstractReserveBehavior{T}, uc::AbstractFleetUnitCommitmentBehavior) where T
    m = lowermodel(sim(c))
    car = carrier(getport(c, b.data.pname))
    def = _defaultmodifier(carrierstyle(car))
    mod_uc = uc.modifier
    mod_b = b.data.modifier
    @argcheck (mod_uc === mod_b || (mod_uc === defaultmodifier && mod_b === def) || (mod_b === defaultmodifier && mod_uc === def)) "$(behaviorname(b)) modifier must match unit commitment modifier for port '$(b.data.pname)'"
    msh = mesh(c)
    _d = uc.data.startup  # used only for :up r_fast
    max_capacity = uc.unitsize .* _state(uc).data
    if b.data.sense == :up
        @constraint(m, b.r_online.data .<= (max_capacity .- (_com(uc) + _var(uc)).data))
    else
        @constraint(m, b.r_online.data .<= (_com(uc) + _var(uc)).data)
    end
    # r_online cannot exceed committed capacity (unitsize * state)
    @constraint(m, b.r_online.data .<= max_capacity)
    # Fast channel: step wise because availability depends on dt vs startup/shutdown duration.
    # Up: r_fast from off-units when _d <= dt[t] (unit can complete startup in step). Down: from
    # on-units not in shutdown when _d_sd <= dt[t]; units in shutdown excluded to avoid overlap with dispatch.
    if b.data.sense == :up
        cap_beh = getcapacitybehavior(c, b.data.pname)
        nb_max = _nbunitsmax(cap_beh)
        off_cap = (nb_max .- _state(uc).data) .* uc.unitsize .* uc.data.startupratio
        for t in eachstep(msh)
            dt_t = Float64(weight(msh, t))
            if _d <= dt_t
                @constraint(m, b.r_fast.data[t] <= off_cap[t])
            else
                # step shorter than startup duration -> no fast-start in this step
                @constraint(m, b.r_fast.data[t] == 0)
            end
        end
    else
        _d_sd = uc.data.shutdown
        for t in eachstep(msh)
            dt_t = Float64(weight(msh, t))
            if _d_sd <= dt_t
                # on-units not in shutdown (excluded so as not to double-count with dispatch)
                stable_on_t = _state(uc).data[t] - uc.shutdown.data[t]
                @constraint(m, b.r_fast.data[t] <= stable_on_t * uc.unitsize * uc.data.shutdownratio)
            else
                # step shorter than shutdown duration -> no fast-down in this step
                @constraint(m, b.r_fast.data[t] == 0)
            end
        end
    end
    @constraint(m, b.r.data .== b.r_online.data .+ b.r_fast.data)
end

# ramping: total flow change  +r or -r must stay within ramp; need ramping on same port and sense.
function _apply_constraints_reserve_ramping!(c::Component{T}, b::AbstractReserveBehavior{T}) where T
    ramp_behavior = getrampingbehavior(c, b.data.pname, b.data.sense)
    if isnothing(ramp_behavior)
        return nothing
    end
    car = carrier(getport(c, b.data.pname))
    def = _defaultmodifier(carrierstyle(car))
    mod_ramp = ramp_behavior.data.modifier
    mod_b = b.data.modifier
    @argcheck (mod_ramp === mod_b || (mod_ramp === defaultmodifier && mod_b === def) || (mod_b === defaultmodifier && mod_ramp === def)) "$(behaviorname(b)) modifier must match ramping modifier for port '$(b.data.pname)'"
    uc = getunitcommitmentbehavior(c, b.data.pname)
    __apply_constraints_reserve_ramping!(c, b, ramp_behavior, uc)
end
# non-UC: flow_diff = flow[t+1]−flow[t]; :up -> flow_diff + r <= max_ramp, :down -> flow_diff − r >= −max_ramp.
function __apply_constraints_reserve_ramping!(c::Component{T}, b::AbstractReserveBehavior{T}, ramp_behavior::RampingBehavior, uc::Nothing) where T
    m = lowermodel(sim(c))
    msh = mesh(c)
    ramp_val = ramp_behavior.data.val
    flow = b.data.modifier(getport(c, b.data.pname))
    flow_diff = shift(flow, 1) - flow
    max_ramp = ramp_val .* weight(msh)
    if b.data.sense == :up
        @constraint(m, flow_diff.data .+ b.r.data .<= max_ramp)
    else
        @constraint(m, flow_diff.data .- b.r.data .>= -max_ramp)
    end
end
# UC: flow_diff from _var(uc), max_ramp scaled by _state(uc). Ramp applies to r_online only; r_fast
# is within step delivery so not limited by inter step ramp.
function __apply_constraints_reserve_ramping!(c::Component{T}, b::AbstractReserveBehavior{T}, ramp_behavior::RampingBehavior, uc::AbstractUnitCommitmentBehavior) where T
    m = lowermodel(sim(c))
    msh = mesh(c)
    ramp_val = ramp_behavior.data.val
    var = _var(uc)
    car = getport(c, b.data.pname).carrier
    flow_diff = (shift(var, 1) - var) .* b.data.modifier(car) ./ uc.modifier(car)
    max_ramp = _state(uc) .* weight(msh) .* ramp_val
    if b.data.sense == :up
        @constraint(m, flow_diff.data .+ b.r_online.data .<= max_ramp.data)
    else
        @constraint(m, flow_diff.data .- b.r_online.data .>= .-max_ramp.data)
    end
end

# storage: only sense :up is limited by stored energy (discharge headroom = level, charge headroom = cap−level).
# down-reserve does not release stored energy in this formulation so no level bound.
function _apply_constraints_reserve_storage!(c::Component{T}, b::AbstractReserveBehavior{T}) where T
    __apply_constraints_reserve_storage!(c, b, model(c))
    return nothing
end
__apply_constraints_reserve_storage!(::Component{T}, ::AbstractReserveBehavior{T}, ::AbstractModel) where T = nothing

# up-reserve on output -> r <= eta*level/duration (discharge headroom); on input -> r <= (cap−level)/(eta*duration) (charge headroom).
# down-reserve has no level limit (reduces output or increases charge; no level ceiling here).
function __apply_constraints_reserve_storage!(c::Component{T}, b::AbstractReserveBehavior{T}, m::Union{BasicStorageModel,LazyStorageModel}) where T
    b.data.sense != :up && return nothing
    lm = lowermodel(sim(c))
    level = b.data.modifier(getport(c, "level"))
    eta = _get_eta_storage(c, b.data.pname, m)
    if hasoutput(c, b.data.pname)
        @constraint(lm, b.r.data .<= eta .* level.data ./ b.data.duration)
    elseif hasinput(c, b.data.pname)
        capacity_level = capacity(c, "level"; multiplier=true)
        if capacity_level isa Stepwise
            capacity_level_data = capacity_level.data
        else
            capacity_level_data = _to_affexpr(capacity_level, lm)
        end
        @constraint(lm, b.r.data .<= (capacity_level_data .- level.data) ./ (eta .* b.data.duration))
    end
end

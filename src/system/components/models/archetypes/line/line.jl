# build ports for a bidirectional line (shared by AC/DC)
#
# The line uses one signed flow variable. Positive values inject power at the
# `from` side and withdraw it at the `to` side; a physical transfer from
# `from` to `to` is therefore represented by a negative value. This preserves
# the historical `_transmissionbalance` sign convention.
#
# The `from_in` and `to_in` ports are zero-valued compatibility ports. They keep
# the existing four-port connection workflow while the two output ports expose
# the two directional bounds:
#   FixedCapacity("from_out", ...) -> upper bound on flow
#   FixedCapacity("to_out", ...)   -> lower bound on flow through -flow <= cap
function _mk_ports(::Type{T}, sim::Sim, mname::String, carrier) where {T}
    ps = PortStructure{T}(sim)
    flow = Stepwise(sim; basename=mname * "_flow", lb=-Inf, ub=Inf)
    zero_flow = Stepwise(zeros(T, nsteps(sim)), sim.mesh)

    addoutput!(ps, "from_out", mname, Port(carrier, flow))
    addinput!(ps, "from_in", mname, Port(carrier, zero_flow))
    addinput!(ps, "to_in", mname, Port(carrier, zero_flow))
    addoutput!(ps, "to_out", mname, Port(carrier, -1.0 * flow))
    return ps, flow
end

# dispatch per line kind
build(m::AbstractTransmissionLine, mname::String) = _build(m, mname)

# AC line: same port layout; with KVL
function _build(m::ACLine, mname::String)
    ps, flow = _mk_ports(exptype(m.sim), m.sim, mname, m.from)
    return ACLineModel{exptype(m.sim)}(m, ps, flow)
end

# DC line: same port layout; no KVL
function _build(m::DCLine, mname::String)
    ps, flow = _mk_ports(exptype(m.sim), m.sim, mname, m.from)
    return DCLineModel{exptype(m.sim)}(m, ps, flow)
end

_apply_constraints!(::AbstractComponent, ::ACLineModel) = nothing
_apply_constraints!(::AbstractComponent, ::DCLineModel) = nothing

modelname(::ACLineModel) = "AC transmission line"
modelname(::DCLineModel) = "DC transmission line"

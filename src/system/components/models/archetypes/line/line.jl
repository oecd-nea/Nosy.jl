# build ports for a bidirectional line (shared by AC/DC)
function _mk_ports(::Type{T}, sim::Sim, mname::String, carrier) where {T}
    ps  = PortStructure{T}(sim)
    f_ft = Stepwise(sim; basename=mname*"_ft", lb=0.0)
    f_tf = Stepwise(sim; basename=mname*"_tf", lb=0.0)
    addoutput!(ps, "from_out", mname, Port(carrier, f_ft))
    addinput!(ps, "from_in", mname, Port(carrier, f_tf))
    addinput!(ps, "to_in", mname, Port(carrier, f_ft))
    addoutput!(ps, "to_out", mname, Port(carrier, f_tf))
    return ps
end

# dispatch per line kind
build(m::AbstractTransmissionLine, mname::String) = _build(m, mname)

# AC line: same port layout; with KVL
_build(m::ACLine, mname::String) = ACLineModel{exptype(m.sim)}(m, _mk_ports(exptype(m.sim), m.sim, mname, m.from))

# DC line: same port layout; no KVL
_build(m::DCLine, mname::String) = DCLineModel{exptype(m.sim)}(m, _mk_ports(exptype(m.sim), m.sim, mname, m.from))

_apply_constraints!(::AbstractComponent, ::ACLineModel) = nothing
_apply_constraints!(::AbstractComponent, ::DCLineModel) = nothing

modelname(::ACLineModel) = "AC transmission line"
modelname(::DCLineModel) = "DC transmission line"
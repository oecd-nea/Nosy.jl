using JuMP: @variable

"""
Basic sink.

Flexibly consumes an input flow. Mirrors `DispatchableSource`.
"""


struct BasicSink{C<:AbstractCarrier} <: AbstractModelData
    sim::Sim
    mesh::RTimeMesh
    carrier::C
end

mesh(m::BasicSink) = m.mesh

"""
    BasicSink(carrier::AbstractCarrier)

Return a `BasicSink` model archetype for carrier `carrier`.
"""
function BasicSink(carrier::AbstractCarrier; mesh::RTimeMesh=sim(carrier).mesh)
    s = sim(carrier)
    return BasicSink(s, _checkmesh(mesh, s.mesh, "Sink"), carrier)
end

struct BasicSinkModel{C<:AbstractCarrier,T<:VAL} <: AbstractModel{T}
    data::BasicSink{C}
    s::PortStructure{T}
end

# return a BasicSinkModel using BasicSink data
function build(m::BasicSink, mname::String)
    vin = Stepwise(m.sim, m.mesh, lb=0., ub=Inf64, binary=false, integer=false, basename=mname * "_" * modifiername(_defaultmodifier(carrierstyle(m.carrier))) * "_in")

    ps = PortStructure{exptype(m.sim)}(m.sim)
    addinput!(ps, "input", mname, Port(m.carrier, vin))

    return BasicSinkModel(m, ps)
end

# no constraints specific to BasicSink
function _apply_constraints!(::BasicSinkModel) end

modelname(::BasicSinkModel) = "basic sink"

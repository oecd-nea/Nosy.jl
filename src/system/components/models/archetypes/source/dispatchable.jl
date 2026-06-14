using JuMP: @variable
using ArgCheck: @argcheck

"""
Dispatchable source.

Flexibly generate an output flow. Mirrors "BasicSink".
"""


struct DispatchableSource{C<:AbstractCarrier} <: AbstractModelData
    sim::Sim
    mesh::RTimeMesh
    carrier::C
end

mesh(m::DispatchableSource) = m.mesh

"""
    DispatchableSource(carrier::AbstractCarrier)

Return a `DispatchableSource` model archetype for carrier `carrier`.
"""
function DispatchableSource(carrier::AbstractCarrier; mesh::RTimeMesh=sim(carrier).mesh)
    s = sim(carrier)
    @argcheck _compatiblemesh(s.mesh, mesh) "Source mesh must be compatible with the simulation mesh"
    return DispatchableSource(s, mesh, carrier)
end

struct DispatchableSourceModel{C<:AbstractCarrier,T<:VAL} <: AbstractModel{T}
    data::DispatchableSource{C}
    s::PortStructure{T}
end

# return a DispatchableSourceModel using DispatchableSource data
function build(m::DispatchableSource, mname::String)
    vout = Stepwise(m.sim, m.mesh, lb=0., ub=Inf64, binary=false, integer=false, basename=mname * "_" * modifiername(_defaultmodifier(carrierstyle(m.carrier))) * "_out")

    ps = PortStructure{exptype(m.sim)}(m.sim)
    addoutput!(ps, "output", mname, Port(m.carrier, vout))

    return DispatchableSourceModel(m, ps)
end

# no constraints specific to DispatchableSource
function _apply_constraints!(::DispatchableSourceModel) end

modelname(::DispatchableSourceModel) = "dispatchable source"

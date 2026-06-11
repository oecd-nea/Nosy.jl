using ArgCheck: @argcheck
using JuMP: @constraint

"""
DC transmission line:
- Only connects PowerCarrier nodes
- No admittance
"""

"""
    DCLine(from::PowerCarrier, to::PowerCarrier; mesh=sim(from).mesh)

Return a `DCLine` model archetype from `from` to `to`.
`DCLine` does not contribute to Kirchhoff Voltage Law (KVL).
"""
struct DCLine <: AbstractTransmissionLine
    sim::Sim
    mesh::RTimeMesh
    from::PowerCarrier
    to::PowerCarrier
    function DCLine(from::PowerCarrier, to::PowerCarrier; mesh::RTimeMesh=sim(from).mesh)
        @argcheck sim(from) === sim(to) "Carriers must belong to the same Sim"
        @argcheck _compatiblemesh(sim(from).mesh, mesh) "Line mesh must be compatible with the simulation mesh"
        new(sim(from), mesh, from, to)
    end
end

mesh(m::DCLine) = m.mesh

struct DCLineModel{T<:VAL} <: AbstractModel{T}
    data::DCLine
    s::PortStructure{T}
end

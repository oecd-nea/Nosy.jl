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
        new(sim(from), _checkmesh(mesh, sim(from).mesh, "Line"), from, to)
    end
end

mesh(m::DCLine) = m.mesh

struct DCLineModel{T<:VAL} <: AbstractModel{T}
    data::DCLine
    s::PortStructure{T}
end

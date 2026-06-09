using ArgCheck: @argcheck
using JuMP: @constraint

"""
    ACLine(from::PowerCarrier, to::PowerCarrier, admittance::Number; mesh=sim(from).mesh)

Return an `ACLine` model archetype from `from` to `to`, with admittance `admittance`.
`ACLine` contributes to Kirchhoff Voltage Law (KVL).
"""
struct ACLine <: AbstractTransmissionLine
    sim::Sim
    mesh::RTimeMesh
    from::PowerCarrier
    to::PowerCarrier
    admittance::Float64
    function ACLine(from::PowerCarrier, to::PowerCarrier, admittance::Number; mesh::RTimeMesh=sim(from).mesh)
        @argcheck admittance > 0 "admittance must be positive"
        @argcheck sim(from) === sim(to) "Carriers must belong to the same Sim"
        new(sim(from), _checkmesh(mesh, sim(from).mesh, "Line"), from, to, Float64(admittance))
    end
end

mesh(m::ACLine) = m.mesh

struct ACLineModel{T<:VAL} <: AbstractModel{T}
    data::ACLine
    s::PortStructure{T}
end

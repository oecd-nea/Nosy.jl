using ArgCheck: @argcheck

"""
Demand.

Consumes an input flow according to a series.
The series is not normalised, it is the actual consumption value.
"""

struct Demand{C<:AbstractCarrier} <: AbstractModelData
    sim::Sim
    mesh::RTimeMesh
    carrier::C
    series::Stepwise{Float64} # expressed in the defaultmodifier of carrier
end

mesh(m::Demand) = m.mesh

"""
    Demand(carrier::AbstractCarrier, series; modifier=defaultmodifier, mesh=sim(carrier).mesh)

Return a `Demand` model archetype for carrier `carrier` with a non-negative series `series`.
The parameter `series` can be either a Vector (of length equal to number of hours or steps) or a Number.
If `modifier` is provided, `series` is interpreted in the modified carrier unit.
The `mesh` argument defines the component mesh used by the demand port.
"""
function Demand(carrier::AbstractCarrier, series; modifier=defaultmodifier, mesh::RTimeMesh=sim(carrier).mesh)
    @argcheck all(series .>= 0.) "The series cannot be negative"
    s = sim(carrier)
    @argcheck _compatiblemesh(s.mesh, mesh) "Demand mesh must be compatible with the simulation mesh"

    user_modifier = remesh(modifier(carrier), mesh)
    carrier_modifier = remesh(defaultmodifier(carrier), mesh)
    _series = Stepwise(series, mesh) ./ (user_modifier .* carrier_modifier)

    return Demand(s, mesh, carrier, Stepwise(_series, mesh))
end

struct DemandModel{T<:VAL,C<:AbstractCarrier} <: AbstractModel{T}
    data::Demand{C}
    s::PortStructure{T}
end

# return a DemandModel using Demand data
function build(m::Demand, mname::String)

    ps = PortStructure{exptype(m.sim)}(m.sim)
    addinput!(ps, "input", mname, Port(m.carrier, m.series))

    return DemandModel(m, ps)
end

# no constraints specific to DemandModel
function _apply_constraints!(::DemandModel) end

modelname(::DemandModel) = "demand"

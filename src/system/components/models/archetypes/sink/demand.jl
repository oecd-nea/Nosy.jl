using ArgCheck: @argcheck

"""
Demand.

Consumes an input flow according to a series.
The series is not normalised, it is the actual consumption value.
"""

struct Demand{C<:AbstractCarrier} <: AbstractModelData
    sim::Sim
    carrier::C
    series::Stepwise{Float64} # expressed in the defaultmodifier of carrier
end

"""
    Demand(carrier::AbstractCarrier, series; modifier=defaultmodifier)

Return a `Demand` model archetype for carrier `carrier` with a non-negative series `series`.
The parameter `series` can be either a Vector (of length equal to number of hours or steps) or a Number.
If `modifier` is provided, `series` is interpreted in the modified carrier unit.
"""
function Demand(carrier::AbstractCarrier, series; modifier=defaultmodifier)
    @argcheck all(series .>= 0.) "The series cannot be negative"
    s = sim(carrier)
    
    _series = Stepwise(series, s.mesh) ./ (Stepwise(modifier(carrier), s.mesh) .* Stepwise(defaultmodifier(carrier), s.mesh))

    return Demand(s, carrier, Stepwise(_series, s.mesh))
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

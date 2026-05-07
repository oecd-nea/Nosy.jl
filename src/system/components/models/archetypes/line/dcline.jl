using ArgCheck: @argcheck
using JuMP: @constraint

"""
DC transmission line:
- Only connects PowerCarrier nodes
- No admittance
"""

"""
    DCLine(from::PowerCarrier, to::PowerCarrier)

Return a `DCLine` model archetype from `from` to `to`.
`DCLine` does not contribute to Kirchhoff Voltage Law (KVL).
"""
struct DCLine <: AbstractTransmissionLine
    sim::Sim
    from::PowerCarrier
    to::PowerCarrier
    function DCLine(from::PowerCarrier, to::PowerCarrier)
        @argcheck sim(from) === sim(to) "Carriers must belong to the same Sim"
        new(sim(from), from, to)
    end
end

struct DCLineModel{T<:VAL} <: AbstractModel{T}
    data::DCLine
    s::PortStructure{T}
end
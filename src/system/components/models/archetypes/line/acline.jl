using ArgCheck: @argcheck
using JuMP: @constraint

"""
    ACLine(from::PowerCarrier, to::PowerCarrier, admittance::Number)

Return an `ACLine` model archetype from `from` to `to`, with admittance `admittance`.
`ACLine` contributes to Kirchhoff Voltage Law (KVL).
"""
struct ACLine <: AbstractTransmissionLine
    sim::Sim
    from::PowerCarrier
    to::PowerCarrier
    admittance::Float64
    function ACLine(from::PowerCarrier, to::PowerCarrier, admittance::Number)
        @argcheck admittance > 0 "admittance must be positive"
        @argcheck sim(from) === sim(to) "Carriers must belong to the same Sim"
        new(sim(from), from, to, Float64(admittance))
    end
end

struct ACLineModel{T<:VAL} <: AbstractModel{T}
    data::ACLine
    s::PortStructure{T}
end
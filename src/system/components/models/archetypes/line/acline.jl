using ArgCheck: @argcheck
using JuMP: @constraint

"""
    ACLine(s::Sim, from::PowerCarrier, to::PowerCarrier, admittance::Float64)
Return a ACLine model from `from` to `to`, with admittance `admittance`.
ACLine does contribute to Kirchhoff Voltage Law (KVL).
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
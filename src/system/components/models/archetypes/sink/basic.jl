using JuMP: @variable

"""
Basic sink.

Flexibly consumes an input flow. Mirrors "BasicSink".
"""


struct BasicSink{C<:AbstractCarrier} <: AbstractModelData
    sim::Sim
    carrier::C
end

"""
    BasicSink(carrier::AbstractCarrier)
Return a model BasicSink model for carrier `carrier`.
"""
function BasicSink(carrier::AbstractCarrier)
    return BasicSink(sim(carrier), carrier)
end

struct BasicSinkModel{C<:AbstractCarrier,T<:VAL} <: AbstractModel{T}
    data::BasicSink{C}
    s::PortStructure{T}
end

# return a BasicSinkModel using BasicSink data
function build(m::BasicSink, mname::String)
    vin = Stepwise(m.sim, lb=0., ub=Inf64, binary=false, integer=false, basename=mname * "_" * modifiername(_defaultmodifier(carrierstyle(m.carrier))) * "_in")

    ps = PortStructure{exptype(m.sim)}(m.sim)
    addinput!(ps, "input", Port(m.carrier, vin))

    return BasicSinkModel(m, ps)
end

# no constraints specific to BasicSink
function _apply_constraints!(::BasicSinkModel) end

modelname(::BasicSinkModel) = "basic sink"
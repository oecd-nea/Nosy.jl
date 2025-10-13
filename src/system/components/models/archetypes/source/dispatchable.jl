using JuMP: @variable

"""
Dispatchable source.

Flexibly generate an output flow. Mirrors "BasicSink".
"""


struct DispatchableSource{C<:AbstractCarrier} <: AbstractModelData
    sim::Sim
    carrier::C
end

"""
    DispatchableSource(carrier::AbstractCarrier)
Return a model DispatchableSource model for carrier `carrier`.
"""
function DispatchableSource(carrier::AbstractCarrier)
    return DispatchableSource(sim(carrier), carrier)
end

struct DispatchableSourceModel{C<:AbstractCarrier,T<:VAL} <: AbstractModel{T}
    data::DispatchableSource{C}
    s::PortStructure{T}
end

# return a DispatchableSourceModel using DispatchableSource data
function build(m::DispatchableSource, mname::String)
    vout = Stepwise(m.sim, lb=0., ub=Inf64, binary=false, integer=false, basename=mname * "_" * modifiername(_defaultmodifier(carrierstyle(m.carrier))) * "_out")

    ps = PortStructure{exptype(m.sim)}(m.sim)
    addoutput!(ps, "output", mname, Port(m.carrier, vout))

    return DispatchableSourceModel(m, ps)
end

# no constraints specific to DispatchableSource
function _apply_constraints!(::DispatchableSourceModel) end

modelname(::DispatchableSourceModel) = "dispatchable source"
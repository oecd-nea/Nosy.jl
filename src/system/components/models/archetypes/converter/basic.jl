using ArgCheck: @argcheck
using JuMP: @variable

"""
Basic converter.

Converter from a carrier to another, following a given ratio.
"""


struct BasicConverter{C1<:AbstractCarrier,C2<:AbstractCarrier,M<:Function} <: AbstractModelData
    sim::Sim
    input::C1
    output::C2
    ratio::Stepwise{Float64}
    modifier::M
end

"""
    BasicConverter(input::AbstractCarrier, output::AbstractCarrier, ratio)
Return a model BasicConverter model which converts carrier `input` into `output` with a ratio `ratio`.
The ratio can be a number or a time series.
The modifier is applied to both input and output e.g. with modifier=mass, then mass(output) = mass(input) * ratio at each step.
"""
function BasicConverter(input::AbstractCarrier, output::AbstractCarrier; ratio=1., modifier::Function=defaultmodifier)
    s = sim(input)

    if modifier != defaultmodifier
        @argcheck hasmodifier(input, modifier) "$(input.name) not compatible with $modifier"
        @argcheck hasmodifier(output, modifier) "$(input.name) not compatible with $modifier"
    end

    @argcheck ratio isa Number || (ratio isa AbstractVector && (length(ratio) == nsteps(s) || length(ratio) == nhours(s))) "ratio must be either a number or a vector of length $(nhours(s)) or $(nsteps(s))"
    
    return BasicConverter(s, input, output, Stepwise(ratio, s.mesh), modifier)
end

struct BasicConverterModel{C1<:AbstractCarrier,C2<:AbstractCarrier,M<:Function,T<:VAL} <: AbstractModel{T}
    data::BasicConverter{C1,C2,M}
    s::PortStructure{T}
end

# return a BasicConverterModel using BasicConverter data
function build(m::BasicConverter, mname::String)
    vin = Stepwise(m.sim, lb=0., ub=Inf64, binary=false, integer=false, basename=mname * "_" * modifiername(m.modifier) * "_in")
    vout = m.ratio .* m.modifier(m.input) ./ m.modifier(m.output) .* vin

    ps = PortStructure{exptype(m.sim)}(m.sim)
    addinput!(ps, "input", mname, Port(m.input, vin))
    addoutput!(ps, "output", mname, Port(m.output, vout))

    return BasicConverterModel(m, ps)
end

# no constraints specific to BasicConverter
# model already encapsulated in affine relation between input and output
function _apply_constraints!(::BasicConverterModel) end

modelname(::BasicConverterModel) = "basic converter"
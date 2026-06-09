using ArgCheck: @argcheck
using JuMP: @variable

"""
Basic converter.

Converter from a carrier to another, following a given ratio.
"""


struct BasicConverter{C1<:AbstractCarrier,C2<:AbstractCarrier,M<:Function} <: AbstractModelData
    sim::Sim
    mesh::RTimeMesh
    input::C1
    output::C2
    ratio::Stepwise{Float64}
    modifier::M
end

mesh(m::BasicConverter) = m.mesh

"""
    BasicConverter(input::AbstractCarrier, output::AbstractCarrier; ratio=1., modifier::Function=defaultmodifier, mesh=sim(input).mesh)

Return a `BasicConverter` model archetype that converts carrier `input` into `output` with ratio `ratio`.
The ratio can be a number or a time series.
The `mesh` argument defines the component mesh used by both input and output ports.
"""
function BasicConverter(input::AbstractCarrier, output::AbstractCarrier; ratio=1., modifier::Function=defaultmodifier, mesh::RTimeMesh=sim(input).mesh)
    s = sim(input)
    @argcheck sim(input) === sim(output) "Input and output carriers must belong to the same Sim"
    mesh = _checkmesh(mesh, s.mesh, "Converter")

    if modifier != defaultmodifier
        @argcheck hasmodifier(input, modifier) "$(input.name) not compatible with $modifier"
        @argcheck hasmodifier(output, modifier) "$(output.name) not compatible with $modifier"
    end

    @argcheck ratio isa Number || (ratio isa AbstractVector && (length(ratio) == nsteps(mesh) || length(ratio) == nhours(mesh))) "ratio must be either a number or a vector of length $(nhours(mesh)) or $(nsteps(mesh))"
    
    return BasicConverter(s, mesh, input, output, Stepwise(ratio, mesh), modifier)
end

struct BasicConverterModel{C1<:AbstractCarrier,C2<:AbstractCarrier,M<:Function,T<:VAL} <: AbstractModel{T}
    data::BasicConverter{C1,C2,M}
    s::PortStructure{T}
end

# return a BasicConverterModel using BasicConverter data
function build(m::BasicConverter, mname::String)
    vin = Stepwise(m.sim, m.mesh, lb=0., ub=Inf64, binary=false, integer=false, basename=mname * "_" * modifiername(m.modifier) * "_in")
    input_modifier = remesh(m.modifier(m.input), m.mesh)
    output_modifier = remesh(m.modifier(m.output), m.mesh)
    vout = m.ratio .* input_modifier ./ output_modifier .* vin

    ps = PortStructure{exptype(m.sim)}(m.sim)
    addinput!(ps, "input", mname, Port(m.input, vin))
    addoutput!(ps, "output", mname, Port(m.output, vout))

    return BasicConverterModel(m, ps)
end

# no constraints specific to BasicConverter
# model already encapsulated in affine relation between input and output
function _apply_constraints!(::BasicConverterModel) end

modelname(::BasicConverterModel) = "basic converter"

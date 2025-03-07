using ArgCheck: @argcheck
using JuMP: @constraint

"""
Basic storage.

Has a input, output, level, applies storage equality constraint.
"""


struct BasicStorage{CI<:AbstractCarrier,CO<:AbstractCarrier,CL<:AbstractCarrier,M<:Function} <: AbstractModelData
    sim::Sim
    input::CI
    output::CO
    level::CL
    modifier::M
    eff_i::Float64 # efficiency of input
    eff_o::Float64 # efficiency of output

    function BasicStorage(input::CI, output::CO, level::CL, modifier::M, eff_i::Float64, eff_o::Float64) where {CI,CO,CL,M}
        @argcheck eff_i >= 0. "Efficiency of input must be positive or zero"
        @argcheck eff_o > 0. "Efficiency of output must be strictly positive or zero"
        @argcheck hasmodifier(input, modifier) "input carrier is not compatible with given modifier"
        @argcheck hasmodifier(output, modifier) "output carrier is not compatible with given modifier"
        @argcheck hasmodifier(level, modifier) "level carrier is not compatible with given modifier"
        @argcheck input.sim == output.sim == level.sim "input, output and level carriers must have the same simulation"
        return new{CI,CO,CL,M}(input.sim, input, output, level, modifier, eff_i, eff_o)
    end
end

"""
    BasicStorage(carrier::AbstractCarrier; eff_i::Float64=1., eff_o::Float64=1., modifier=_defaultmodifier(carrierstyle(carrier)))
Return a model BasicStorage model associated with carrier `carrier`.
The model also has the input effiency `input` and output efficiency `output` (inferior to 1 for losses).
"""
function BasicStorage(carrier::AbstractCarrier; eff_i::Float64=1., eff_o::Float64=1., modifier=_defaultmodifier(carrierstyle(carrier)))
    return BasicStorage(carrier, carrier, carrier, modifier, eff_i, eff_o)
end

"""
    BasicStorage(input::AbstractCarrier, output::AbstractCarrier, level::AbstractCarrier, modifier::Function; eff_i::Float64=1., eff_o::Float64=1.)
Return a model BasicStorage model associated with:
  * `input`: carrier of input
  * `output`: carrier of output
  * `level`: carrier of level
  * `modifier`: modifier for all carriers
  * `eff_i`: efficiency of input (inferior to 1 for losses)
  * `eff_o`: efficiency of output (inferior to 1 for losses)
The model also has the input effiency `input` and output efficiency `output`.
"""
function BasicStorage(input::AbstractCarrier, output::AbstractCarrier, level::AbstractCarrier, modifier::Function; eff_i::Float64=1., eff_o::Float64=1.)
    return BasicStorage(input, output, level, modifier, eff_i, eff_o)
end

struct BasicStorageModel{CI<:AbstractCarrier,CO<:AbstractCarrier,CL<:AbstractCarrier,M<:Function,T<:VAL} <: AbstractModel{T}
    data::BasicStorage{CI,CO,CL,M}
    s::PortStructure{T}
end

# return a BasicStorageModel using BasicStorage data
function build(m::BasicStorage, mname::String)
    _input = Stepwise(m.sim, lb=0., ub=Inf64, binary=false, integer=false, basename=mname * "_" * modifiername(m.modifier) * "_input")
    _output = Stepwise(m.sim, lb=0., ub=Inf64, binary=false, integer=false, basename=mname * "_" * modifiername(m.modifier) * "_output")
    _level = Stepwise(m.sim, lb=0., ub=Inf64, binary=false, integer=false, basename=mname * "_" * modifiername(m.modifier) * "_level")
    
    ps = PortStructure{exptype(m.sim)}(m.sim)
    addinput!(ps, "input", Port(m.input, _input))
    addoutput!(ps, "output", Port(m.output, _output))
    addlevel!(ps, "level", Port(m.level, _level))

    return BasicStorageModel(m, ps)
end


# implementation of special case for component / model constraints
# this constraint is applied after the joint flows built
# equation:
# level[t+1] - level[t] = 1/2 (in[t+1] + in[t]) * eff_i - 1/2 (out[t+1] + out[t]) / eff_o (+ taking into account the weight of the timestep)

function _apply_constraints!(c::AbstractComponent, m::BasicStorageModel) 
    # storage constraint at each timestep
    _in = m.data.modifier(getport(m.s, "input"))
    _out = m.data.modifier(getport(m.s, "output"))
    _level = m.data.modifier(getport(m.s, "level"))
    
    # constraint: conservation of modified, efficiency-weighted flows & storage
    # we consider flow varies linearly during a timestep
    @constraint(lowermodel(sim(c)), 
        (shift(_level,1) - _level).data .== (((shift(_in,1) + _in) * m.data.eff_i - (shift(_out,1) + _out) / m.data.eff_o) .* weight(sim(c).mesh) / 2.).data
    )

end

modelname(::BasicStorageModel) = "basic storage"
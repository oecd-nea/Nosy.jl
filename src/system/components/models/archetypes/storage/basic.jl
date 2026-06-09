using ArgCheck: @argcheck
using JuMP: @constraint

"""
Basic storage.

Has input, output, and level ports, and applies a storage equality constraint.
"""


struct BasicStorage{CI<:AbstractCarrier,CO<:AbstractCarrier,CL<:AbstractCarrier,M<:Function} <: AbstractModelData
    sim::Sim
    mesh::RTimeMesh
    input::CI
    output::CO
    level::CL
    modifier::M
    eff_i::Float64 # efficiency of input
    eff_o::Float64 # efficiency of output
    self_discharge::Float64 # between 0 and 1
    simplified::Bool

    function BasicStorage(input::CI, output::CO, level::CL, modifier::M, eff_i::Number, eff_o::Number, self_discharge::Number, simplified::Bool, mesh::TimeMesh) where {CI,CO,CL,M}
        @argcheck eff_i >= 0. "Efficiency of input must be positive or zero"
        @argcheck eff_o > 0. "Efficiency of output must be strictly positive"
        @argcheck 0 <= self_discharge <= 1 "Self-discharge must be between 0 and 1"
        @argcheck hasmodifier(input, modifier) "input carrier is not compatible with given modifier"
        @argcheck hasmodifier(output, modifier) "output carrier is not compatible with given modifier"
        @argcheck hasmodifier(level, modifier) "level carrier is not compatible with given modifier"
        @argcheck input.sim == output.sim == level.sim "input, output and level carriers must have the same simulation"
        return new{CI,CO,CL,M}(input.sim, _checkmesh(mesh, input.sim.mesh, "Storage"), input, output, level, modifier, Float64(eff_i), Float64(eff_o), Float64(self_discharge), simplified)
    end
end

mesh(m::BasicStorage) = m.mesh

"""
    BasicStorage(carrier::AbstractCarrier; eff_i::Float64=1., eff_o::Float64=1., self_discharge::Float64=0., modifier=_defaultmodifier(carrierstyle(carrier)), simplified::Bool=false, mesh=sim(carrier).mesh)

Return a `BasicStorage` model archetype using `carrier` for input, output, and level.
The model uses input efficiency `eff_i`, output efficiency `eff_o`, and hourly self-discharge rate `self_discharge`.
The `mesh` argument defines the component mesh used by input, output, level,
and the storage balance.
"""
function BasicStorage(carrier::AbstractCarrier; eff_i::Float64=1., eff_o::Float64=1., self_discharge::Float64=0., modifier=_defaultmodifier(carrierstyle(carrier)), simplified::Bool=false, mesh::RTimeMesh=sim(carrier).mesh)
    return BasicStorage(carrier, carrier, carrier, modifier, eff_i, eff_o, self_discharge, simplified, mesh)
end

"""
    BasicStorage(input::AbstractCarrier, output::AbstractCarrier, level::AbstractCarrier, modifier::Function; eff_i::Float64=1., eff_o::Float64=1., self_discharge::Float64=0., simplified::Bool=false, mesh=sim(input).mesh)

Return a `BasicStorage` model archetype associated with:
  * `input`: carrier of input
  * `output`: carrier of output
  * `level`: carrier of level
  * `modifier`: modifier for all carriers
  * `eff_i`: input efficiency
  * `eff_o`: output efficiency
  * `self_discharge`: hourly rate of self-discharge
  * `simplified`: if `true`, use step flows instead of trapezoidal integration
  * `mesh`: component mesh used by input, output, level, and the storage balance

Storage is periodic: the step after the last step is the first step.
"""
function BasicStorage(input::AbstractCarrier, output::AbstractCarrier, level::AbstractCarrier, modifier::Function; eff_i::Float64=1., eff_o::Float64=1., self_discharge::Float64=0., simplified::Bool=false, mesh::RTimeMesh=sim(input).mesh)
    return BasicStorage(input, output, level, modifier, eff_i, eff_o, self_discharge, simplified, mesh)
end

struct BasicStorageModel{CI<:AbstractCarrier,CO<:AbstractCarrier,CL<:AbstractCarrier,M<:Function,T<:VAL} <: AbstractModel{T}
    data::BasicStorage{CI,CO,CL,M}
    s::PortStructure{T}
end

# return a BasicStorageModel using BasicStorage data
function build(m::BasicStorage, mname::String)
    _input = Stepwise(m.sim, m.mesh, lb=0., ub=Inf64, binary=false, integer=false, basename=mname * "_" * modifiername(m.modifier) * "_input")
    _output = Stepwise(m.sim, m.mesh, lb=0., ub=Inf64, binary=false, integer=false, basename=mname * "_" * modifiername(m.modifier) * "_output")
    _level = Stepwise(m.sim, m.mesh, lb=0., ub=Inf64, binary=false, integer=false, basename=mname * "_" * modifiername(m.modifier) * "_level")
    
    ps = PortStructure{exptype(m.sim)}(m.sim)
    addinput!(ps, "input", mname, Port(m.input, _input))
    addoutput!(ps, "output", mname, Port(m.output, _output))
    addlevel!(ps, "level", mname, Port(m.level, _level))

    return BasicStorageModel(m, ps)
end


# implementation of special case for component / model constraints
# this constraint is applied after the joint flows built
# equation:
# level[t+1] - level[t] = 1/2 (in[t+1] + in[t]) * eff_i - 1/2 (out[t+1] + out[t]) / eff_o (+ taking into account the weight of the timestep)

function _apply_constraints!(c::AbstractComponent, m::BasicStorageModel) 
    # storage constraint at each timestep
    _in = m.data.modifier(getport(c, "input"))
    _out = m.data.modifier(getport(c, "output"))
    _level = m.data.modifier(getport(c, "level"))
    
    # multiplicator representing 1 - self-discharge, taking timestep duration into account
    # NB multiplicator does not consider variation of level, it is applied to initial level at each step
    sdmult = exp.(- m.data.self_discharge .* weight(mesh(c)))

    # constraint: conservation of modified, efficiency-weighted flows & storage
    if m.data.simplified
        # step flow
        @constraint(lowermodel(sim(c)), 
            (shift(_level,1) - _level .* sdmult).data .== ((_in * m.data.eff_i - _out / m.data.eff_o) .* weight(mesh(c))).data
        )
    else
        # we consider flow varies linearly during a timestep
        @constraint(lowermodel(sim(c)), 
            (shift(_level,1) - _level .* sdmult).data .== (((shift(_in,1) + _in) * m.data.eff_i - (shift(_out,1) + _out) / m.data.eff_o) .* weight(mesh(c)) / 2.).data
        )
    end

end

modelname(::BasicStorageModel) = "basic storage"

# helper function to get efficiency from storage models
function _get_eta_storage(c::AbstractComponent, pname::String, m::BasicStorageModel)
    @argcheck (hasinput(c, pname) || hasoutput(c, pname)) "Port '$pname' must be an input or output port"
    hasoutput(c, pname) && return m.data.eff_o
    return m.data.eff_i
end

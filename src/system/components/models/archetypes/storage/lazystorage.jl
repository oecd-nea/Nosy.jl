using OrderedCollections: LittleDict
using ArgCheck: @argcheck
using JuMP: @constraint

"""
Lazy storage.

Has a level port and applies a storage equality constraint to joint flows.
"""


struct LazyStorage{C<:AbstractCarrier,M<:Function} <: AbstractModelData
    sim::Sim
    mesh::RTimeMesh
    level::C # only level is provided by component, other ports are added as joint flows (free / linked)
    modifier::M # the balance equation will be performed at the component level after applying this modifier
    eff::LittleDict{String,Float64} # dictionary for efficiencies
    self_discharge::Float64 # hourly ratio, between 0 and 1
    simplified::Bool
end

mesh(m::LazyStorage) = m.mesh

"""
    LazyStorage(level::AbstractCarrier; modifier::Function=defaultmodifier, eff=nothing, self_discharge=0., simplified::Bool=false)

Return a `LazyStorage` model archetype with a level of carrier `level`.
The lazy storage constraint is applied to the level and associated joint flows after applying `modifier` to flows.
Storage is periodic: the step after the last step is the first step.
"""
function LazyStorage(level::AbstractCarrier; modifier::Function=defaultmodifier, eff=nothing, self_discharge=0., simplified::Bool=false, mesh::RTimeMesh=sim(level).mesh)
    s = sim(level)
    @argcheck _compatiblemesh(s.mesh, mesh) "Storage mesh must be compatible with the simulation mesh"

    if modifier != defaultmodifier
        @argcheck hasmodifier(level, modifier) "$(name(level)) not compatible with $modifier"
    end
    
    if isnothing(eff)
        d = LittleDict{String,Float64}()
    else
        d = convert(LittleDict{String,Float64}, eff)
    end

    return LazyStorage(s, mesh, level, modifier, d, self_discharge, simplified)
end

struct LazyStorageModel{C<:AbstractCarrier,M<:Function,T<:VAL} <: AbstractModel{T}
    data::LazyStorage{C,M}
    s::PortStructure{T}
end

# return a LazyStorageModel using LazyStorage data
function build(m::LazyStorage, mname::String)
    level = Stepwise(m.sim, m.mesh, lb=0., ub=Inf64, binary=false, integer=false, basename=mname * "_" * modifiername(m.modifier) * "_level")
    
    ps = PortStructure{exptype(m.sim)}(m.sim)
    addlevel!(ps, "level", mname, Port(m.level, level))

    return LazyStorageModel(m, ps)
end

function _geteff(m::LazyStorageModel, pname::String)
    @argcheck haskey(m.data.eff, pname) "Lazy storage has no efficiency for $pname. Please fill in `eff` argument."
    return m.data.eff[pname]
end

# helper function to get efficiency from storage models
function _get_eta_storage(c::AbstractComponent, pname::String, m::LazyStorageModel)
    @argcheck (hasinput(c, pname) || hasoutput(c, pname)) "Port '$pname' must be an input or output port"
    return _geteff(m, pname)
end

# implementation of special case for component / model constraints
# this constraint is applied after the joint flows built
function _apply_constraints!(c::AbstractComponent, m::LazyStorageModel) 
    # Special care: do not apply bluntly default modifier to all carriers
    # instead, define modifier as the default modifier as the model 
    # and apply the same modifier to all carriers
    if m.data.modifier == defaultmodifier
        mod = _defaultmodifier(carrierstyle(m.data.level))
    else
        mod = m.data.modifier
    end

    # storage constraint at each timestep
    _in = sum(_geteff(m, k) * v for (k,v) in _balance(c, :input, mod, collapse=false, aggregate=false))
    _out = sum(_geteff(m, k) * v for (k,v) in _balance(c, :output, mod, collapse=false, aggregate=false))
    _lev = mod(first(values(_level(m.s).d)))

    # multiplicator representing 1 - self-discharge, taking timestep duration into account
    # NB multiplicator does not consider variation of level, it is applied to initial level at each step
    sdmult = exp.(- m.data.self_discharge .* weight(mesh(c)))

    # constraint: conservation of modified, efficiency-weighted flows & storage
    if m.data.simplified
        # basic step function for flow... reduce number of terms in equation
        @constraint(lowermodel(sim(m)), 1. ./ weight(mesh(m)) .* (shift(_lev,1) -  _lev .* sdmult).data .== (_in - _out).data)
    else
        # we consider flow varies linearly during a timestep
        # constraint is multiplied by 2 both sides to reduce number of operations on GenericAffExpr
        @constraint(lowermodel(sim(m)), 2. ./ weight(mesh(m)) .* (shift(_lev,1) -  _lev .* sdmult).data .== (shift(_in,1) + _in - shift(_out, 1) - _out).data)
    end

end

modelname(::LazyStorageModel) = "lazy storage"

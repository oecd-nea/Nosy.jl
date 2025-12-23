using OrderedCollections: LittleDict
using ArgCheck: @argcheck
using JuMP: @constraint

"""
Lazy storage.

Has a level, applies storage equality constraint
"""


struct LazyStorage{C<:AbstractCarrier,M<:Function} <: AbstractModelData
    sim::Sim
    level::C # only level is provided by component, other ports are added as joint flows (free / linked)
    modifier::M # the balance equation will be performed at the component level after appying this modifier
    eff::LittleDict{String,Float64} # dictionary for efficiencies
    simplified::Bool
end

"""
    LazyStorage(level::AbstractCarrier; modifier::Function=defaultmodifier; eff=nothing)
Return a model LazyStorage model which has a level of carrier `level`.
The lazy storage constraint will be applied to the level and the associated joint flows after applying the `modifier` to flows.`. 
NB storage is periodic: the step after the last step is the first step.
"""
function LazyStorage(level::AbstractCarrier; modifier::Function=defaultmodifier, eff=nothing, simplified::Bool=false)
    s = sim(level)

    if modifier != defaultmodifier
        @argcheck hasmodifier(level, modifier) "$(name(level)) not compatible with $modifier"
    end
    
    if isnothing(eff)
        d = LittleDict{String,Float64}()
    else
        d = convert(LittleDict{String,Float64}, eff)
    end

    return LazyStorage(s, level, modifier, d, simplified)
end

struct LazyStorageModel{C<:AbstractCarrier,M<:Function,T<:VAL} <: AbstractModel{T}
    data::LazyStorage{C,M}
    s::PortStructure{T}
end

# return a LazyStorageModel using LazyStorage data
function build(m::LazyStorage, mname::String)
    level = Stepwise(m.sim, lb=0., ub=Inf64, binary=false, integer=false, basename=mname * "_" * modifiername(m.modifier) * "_level")
    
    ps = PortStructure{exptype(m.sim)}(m.sim)
    addlevel!(ps, "level", mname, Port(m.level, level))

    return LazyStorageModel(m, ps)
end

function _geteff(m::LazyStorageModel, pname::String)
    @argcheck haskey(m.data.eff, pname) "Lazy storage has no efficiency for $pname. Please fill in `eff` argument."
    return m.data.eff[pname]
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

    # constraint: conservation of modified, efficiency-weighted flows & storage
    if m.data.simplified
        # basic step function for flow... reduce number of terms in equation
        @constraint(lowermodel(sim(m)), 1. ./ weight(sim(m).mesh) .* (shift(_lev,1) -  _lev).data .== (_in - _out).data)
    else
        # we consider flow varies linearly during a timestep
        # constraint is multiplied by 2 both sides to reduce number of operations on GenericAffExpr
        @constraint(lowermodel(sim(m)), 2. ./ weight(sim(m).mesh) .* (shift(_lev,1) -  _lev).data .== (shift(_in,1) + _in - shift(_out, 1) - _out).data)
    end

end

modelname(::LazyStorageModel) = "lazy storage"
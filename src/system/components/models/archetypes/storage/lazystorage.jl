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
end

"""
    LazyStorage(level::AbstractCarrier; modifier::Function=defaultmodifier; eff=nothing)
Return a model LazyStorage model which has a level of carrier `level`.
The lazy storage constraint will be applied to the level and the associated joint flows after applying the `modifier` to flows.`. 
"""
function LazyStorage(level::AbstractCarrier; modifier::Function=defaultmodifier, eff=nothing)
    s = sim(level)

    if modifier != defaultmodifier
        @argcheck !isnothing(modifier(level)) "$(input.name) not compatible with $modifier"
    end
    
    if isnothing(eff)
        d = LittleDict{String,Float64}()
    else
        d = convert(LittleDict{String,Float64}, eff)
    end

    return LazyStorage(s, level, modifier, d)
end

struct LazyStorageModel{C<:AbstractCarrier,M<:Function,T<:VAL} <: AbstractModel{T}
    data::LazyStorage{C,M}
    s::PortStructure{T}
end

# return a LazyStorageModel using LazyStorage data
function build(m::LazyStorage, mname::String)
    level = Stepwise(m.sim, lb=0., ub=Inf64, binary=false, integer=false, basename=mname * "_" * modifiername(m.modifier) * "_level")
    
    ps = PortStructure{AffExpr}(m.sim)
    addlevel!(ps, "level", Port(m.level, level))

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
        mod = _defaultmodifier(carrierstyle(m.level))
    else
        mod = m.data.modifier
    end

    # storage constraint at each timestep
    _in = sum(_geteff(m, k) * v for (k,v) in balance(c, :input, mod, collapse=false, aggregate=false))
    _out = sum(_geteff(m, k) * v for (k,v) in balance(c, :output, mod, collapse=false, aggregate=false))
    _level = mod(getport(m, "level"))
    
    # constraint: conservation of modified, efficiency-weighted flows & storage
    # constraint is multiplied by 2 both sides to reduce number of operations on AffExpr
    # we consider flow varies linearly during a timestep
    @constraint(sim(m).model, 2. ./ weight(sim(m).mesh) .* (shift(_level,1) -  _level).data .== (shift(_in,1) + _in - shift(_out, 1) - _out).data)

end

modelname(::LazyStorageModel) = "lazy storage"
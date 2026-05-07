using JuMP: @variable
using ArgCheck: @argcheck

"""
Profile source.

Generate an output flow according to a profile.
"""


struct ProfileSource{C<:AbstractCarrier} <: AbstractModelData
    sim::Sim
    carrier::C
    profile::Stepwise{Float64}
    cutoff::Float64
end

"""
    ProfileSource(carrier::AbstractCarrier, profile)

Return a `ProfileSource` model archetype for carrier `carrier` with a non-negative profile `profile`.

If `profile` is a Number: the profile is flat.
If `profile` is a Vector: it defines the profile.

The values of `profile` above `cutoff` will be set to `cutoff`.

Adding a capacity behavior is mandatory.
The profile is not renormalised.
"""
function ProfileSource(carrier::AbstractCarrier, profile; cutoff::Number=Inf64)
    @argcheck all(profile .>= 0.) "The profile cannot be negative"
    @argcheck cutoff >= 0. "The cutoff cannot be negative"
    if isinf(cutoff) && !all(profile .<= 1.) 
        @warn "Some profiles have values superior to 1 and there is no cutoff" 
    end
    s = sim(carrier)
    _profile = min.(cutoff, profile)
    return ProfileSource(s, carrier, Stepwise(_profile, s.mesh), Float64(cutoff))
end

struct ProfileSourceModel{C<:AbstractCarrier,T<:VAL} <: AbstractModel{T}
    data::ProfileSource{C}
    s::PortStructure{T}
end

_profile(m::ProfileSourceModel) = m.data.profile

# return a ProfileSourceModel using ProfileSource data
function build(m::ProfileSource, cname::String)
    vout = fill(-Inf, length(m.profile))
    ps = PortStructure{exptype(m.sim)}(m.sim)
    addoutput!(ps, "output", cname, Port(m.carrier, vout))
    return ProfileSourceModel(m, ps)
end

# no constraints specific to ProfileSource
# however we need to check that a capacity was defined (mandatory for ProfileSource)
function _apply_constraints!(c::AbstractComponent, ::ProfileSourceModel)
    # check that component has a capacity
    if !hascapacitybehavior(c, "output")
        throw(AssertionError("Component $(name(c)) is based on ProfileSource and therefore must have a Capacity behavior on \"output\" port"))
    end
end

modelname(::ProfileSourceModel) = "profile source"

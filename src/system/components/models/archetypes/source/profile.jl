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
end

"""
    ProfileSource(carrier::AbstractCarrier, profile)
Return a model ProfileSource model for carrier `carrier` with a non-negative profile `profile`.
If `profile` is a Number: the profile is flat.
If `profile` is a Vector: it defines the profile.
NB: the profile is not renormalized.
"""
function ProfileSource(carrier::AbstractCarrier, profile)
    @argcheck all(profile .>= 0.) "The profile cannot be negative"
    if !all(profile .<= 1.) 
       @warn "Some profiles have values superior to 1." 
    end
    s = sim(carrier)
    return ProfileSource(s, carrier, Stepwise(profile, s.mesh))
end

struct ProfileSourceModel{C<:AbstractCarrier,T<:VAL} <: AbstractModel{T}
    data::ProfileSource{C}
    cap::T # hidden capacity associated with the default modifier of data.carrier
    s::PortStructure{T}
end

# return a ProfileSourceModel using ProfileSource data
function build(m::ProfileSource, mname::String)
    cap = @variable(m.sim.model, base_name=mname * "_icap", lower_bound=0.)
    vout = m.profile * cap

    ps = PortStructure{AffExpr}(m.sim)
    addoutput!(ps, "output", Port(m.carrier, vout))

    return ProfileSourceModel(m, convert(AffExpr, cap), ps)
end

# no constraints specific to ProfileSource
function _apply_constraints!(::ProfileSourceModel) end

modelname(::ProfileSourceModel) = "profile source"


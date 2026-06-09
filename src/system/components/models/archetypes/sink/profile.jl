using ArgCheck: @argcheck

"""
Profile sink.

Consume an input flow according to a profile.
"""

struct ProfileSink{C<:AbstractCarrier} <: AbstractModelData
    sim::Sim
    mesh::RTimeMesh
    carrier::C
    profile::Stepwise{Float64}
    cutoff::Float64
end

mesh(m::ProfileSink) = m.mesh

"""
    ProfileSink(carrier::AbstractCarrier, profile; cutoff=Inf64)

Return a `ProfileSink` model archetype for carrier `carrier` with a non-negative profile `profile`.

If `profile` is a Number, the profile is flat.
If `profile` is a Vector, it defines the profile.

The values of `profile` above `cutoff` will be set to `cutoff`.

Adding a capacity behavior on `input` is mandatory.
The profile is not renormalised.
"""
function ProfileSink(carrier::AbstractCarrier, profile; cutoff::Number=Inf64, mesh::RTimeMesh=sim(carrier).mesh)
    @argcheck all(profile .>= 0.) "The profile cannot be negative"
    @argcheck cutoff >= 0. "The cutoff cannot be negative"
    if isinf(cutoff) && !all(profile .<= 1.)
        @warn "Some profiles have values superior to 1 and there is no cutoff"
    end
    s = sim(carrier)
    mesh = _checkmesh(mesh, s.mesh, "Sink")
    _profile = min.(cutoff, profile)
    return ProfileSink(s, mesh, carrier, Stepwise(_profile, mesh), Float64(cutoff))
end

struct ProfileSinkModel{C<:AbstractCarrier,T<:VAL} <: AbstractModel{T}
    data::ProfileSink{C}
    s::PortStructure{T}
end

_profile(m::ProfileSinkModel) = m.data.profile

function build(m::ProfileSink, cname::String)
    vin = fill(-Inf, length(m.profile))
    ps = PortStructure{exptype(m.sim)}(m.sim)
    addinput!(ps, "input", cname, Port(m.carrier, Stepwise(vin, m.mesh)))
    return ProfileSinkModel(m, ps)
end

function _apply_constraints!(c::AbstractComponent, ::ProfileSinkModel)
    if !hascapacitybehavior(c, "input")
        throw(AssertionError("Component $(name(c)) is based on ProfileSink and therefore must have a Capacity behavior on \"input\" port"))
    end
end

modelname(::ProfileSinkModel) = "profile sink"

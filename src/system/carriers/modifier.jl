"""
Carrier modifiers.

Carrier modifier interface: let `m` be a modifier,
  * m(c::Carrier) should return a Stepwise{Float64}
"""

# default carrier modifier
_defaultmodifier(::IsEnergyCarrierStyle) = energy
_defaultmodifier(::IsMassCarrierStyle) = mass
_defaultmodifier(c::AbstractCarrier) = _defaultmodifier(carrierstyle(c))

defaultmodifier(c::AbstractCarrier) = _defaultmodifier(c)(c)
defaultmodifier(c::AbstractCarrier, step::Int) = defaultmodifier(c)[step]

# apply modifier to carrier

energy(c::EnergyCarrier) = c.energy
energy(c::MassCarrier) = c.energy
energy(::CO2Carrier) = nothing
energy(c::AbstractCarrier, step::Int) = hasmodifier(c, energy) ? energy(c)[step] : throw(AssertionError("Carrier has no energy"))

mass(c::EnergyCarrier) = c.mass
mass(c::MassCarrier) = c.mass
mass(c::CO2Carrier) = c.mass
mass(c::AbstractCarrier, step::Int) = hasmodifier(c, mass) ? mass(c)[step] : throw(AssertionError("Carrier has no mass"))


co2(::EnergyCarrier) = nothing
co2(::MassCarrier) = nothing
co2(c::CO2Carrier) = c.weight
co2(c::AbstractCarrier, step::Int) = hasmodifier(c, co2) ? co2(c)[step] : throw(AssertionError("Carrier has no co2"))


modifiername(::typeof(mass)) = "mass"
modifiername(::typeof(energy)) = "energy"
modifiername(::typeof(co2)) = "co2"
modifiername(::typeof(defaultmodifier)) = "default"

hasmodifier(c::AbstractCarrier, modifier) = !isnothing(modifier(c))
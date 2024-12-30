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

# apply modifier to carrier

energy(c::EnergyCarrier) = c.energy
energy(c::MassCarrier) = c.energy
energy(::CO2Carrier) = nothing

mass(c::EnergyCarrier) = c.mass
mass(c::MassCarrier) = c.mass
mass(c::CO2Carrier) = c.mass

co2(::EnergyCarrier) = nothing
co2(::MassCarrier) = nothing
co2(c::CO2Carrier) = c.weight

modifiername(::typeof(mass)) = "mass"
modifiername(::typeof(energy)) = "energy"
modifiername(::typeof(co2)) = "co2"
modifiername(::typeof(defaultmodifier)) = "default"

hasmodifier(c::AbstractCarrier, modifier) = !isnothing(modifier(c))
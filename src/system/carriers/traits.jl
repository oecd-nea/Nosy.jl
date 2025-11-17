"""
Carrier traits.
"""

abstract type AbstractCarrierStyle end

struct IsMassCarrierStyle <: AbstractCarrierStyle end
struct IsEnergyCarrierStyle <: AbstractCarrierStyle end

carrierstyle(::AbstractCarrier) = error("not implemented") # please implement for each new carrier

carrierstyle(::EnergyCarrier) = IsEnergyCarrierStyle()
carrierstyle(::MassCarrier) = IsMassCarrierStyle()
carrierstyle(::CO2Carrier) = IsMassCarrierStyle()
carrierstyle(::PowerCarrier)  = IsEnergyCarrierStyle()

using Base: RefValue

"""
Definition of ports.
"""

abstract type AbstractPort{T} end

struct Port{T<:VAL,C<:AbstractCarrier} <: AbstractPort{T}
    carrier::C
    series::Stepwise{T}
    used::RefValue{Bool}
end

"""
    Port(c::AbstractCarrier, s::AbstractVector)
Construct a Port with a time series populated with expressions. Initial "used" state is false.
"""
function Port(c::AbstractCarrier, s::AbstractVector, used::Bool=false)
    return Port(c, Stepwise(_to_affexpr.(s, sim(c).model), sim(c).mesh), RefValue(used))
end

# There is not method besides the natural constructor to construct a Port{Float64,C}.
# During the formulation of the optimisation problem, all ports should be of types Port{<:GenericAffExpr,C}, even if they only carry numbers.

carrier(p::AbstractPort) = p.carrier
series(p::AbstractPort) = p.series
sim(p::AbstractPort) = sim(carrier(p))

"""
    is_used(p::Port)
Return true if the port is already used, false otherwise.
"""
is_used(p::Port) = p.used[]

"""
    set_used!(p::Port)
Set port `used` state to true.
Throw error if port is already used.
"""
function set_used!(p::Port)
    if is_used(p) 
        throw(AssertionError("Port is already used"))
    end
    setindex!(p.used, true)
end

Base.similar(p::Port) = typeof(p)(p.carrier, Stepwise(zeros(eltype(p.series.data), length(p.series.data)), p.series.mesh), p.used)

shallowcopy(p::Port) = typeof(p)(p.carrier, Stepwise(p.series.data, p.series.mesh), p.used)

"""
Apply modification to ports.
"""

_mult(s::Stepwise, p::AbstractPort) = Stepwise(s .* series(p), mesh(s))


mass(p::AbstractPort) = _mass(carrierstyle(carrier(p)), p)

_mass(::IsMassCarrierStyle, p::AbstractPort) = series(p)
_mass(::AbstractCarrierStyle, p::AbstractPort) = __mass(mass(carrier(p)), p)

__mass(::Nothing, p::AbstractPort) = throw(AssertionError("Port does not carry mass"))
__mass(s::Stepwise, p::AbstractPort) = _mult(s::Stepwise, p::AbstractPort)

mass(p::AbstractPort, step::Int) = mass(p.carrier, step) * series(p)[step]

# 

energy(p::AbstractPort) = _energy(carrierstyle(carrier(p)), p)

_energy(::IsEnergyCarrierStyle, p::AbstractPort) = series(p)
_energy(::AbstractCarrierStyle, p::AbstractPort) = __energy(energy(carrier(p)), p)

__energy(::Nothing, p::AbstractPort) = throw(AssertionError("Port does not carry energy"))
__energy(s::Stepwise, p::AbstractPort) = _mult(s::Stepwise, p::AbstractPort)

energy(p::AbstractPort, step::Int) = energy(p.carrier, step) * series(p)[step]

# 

co2(p::AbstractPort) = _co2(carrierstyle(carrier(p)), p)

# no dispatch on trait for CO2
_co2(::AbstractCarrierStyle, p::AbstractPort) = __co2(co2(carrier(p)), p)

__co2(::Nothing, p::AbstractPort) = throw(AssertionError("Port does not carry CO2"))
__co2(s::Stepwise, p::AbstractPort) = _mult(s::Stepwise, p::AbstractPort)

co2(p::AbstractPort, step::Int) = co2(p.carrier, step) * series(p)[step]

# default modifier
_defaultmodifier(p::AbstractPort) = _defaultmodifier(carrier(p)) # return the modifier function
defaultmodifier(p::AbstractPort) = _defaultmodifier(p)(p) # apply the modifier function to the Port

defaultmodifier(p::AbstractPort, step::Int) = defaultmodifier(p.carrier, step) * series(p)[step]

# check whether port has a modifier
# return a boolean
hasmodifier(p::AbstractPort, modifier) = hasmodifier(carrier(p), modifier)

_flow(p::AbstractPort, modifier::Function, step::Int) = modifier(p, step)
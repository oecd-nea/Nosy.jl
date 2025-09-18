"""
Definition of carriers.
"""

using ArgCheck: @argcheck

# conversion of numbers and vectors to Float64 or Vector{Float64}
# this is to avoid construction of Stepwise{Int64} when using integer arguments for energy, weight...
_to_f64(n::Number) = Float64(n)
_to_f64(v::AbstractVector{<:Number}) = Float64.(v)

abstract type AbstractCarrier end

struct MassCarrier <: AbstractCarrier
    name::String
    sim::Sim
    mass::Stepwise{Float64} # not elegant, but avoids dynamic dispatch for modifier, for small cost
    energy::Union{Nothing,Stepwise{Float64}}

    @doc """
        MassCarrier(name::String, sim::Sim; energy=nothing)
    Return a MassCarrier with name `name` associated with Sim `sim`.
    Optional arguments:
      * energy: Number (or abstract vector of numbers, for each hour or step) describing the energy density in MWh/t.
    """
    function MassCarrier(name::String, sim::Sim; energy=nothing)
        if !isnothing(energy)
            energy = Stepwise(_to_f64(energy), sim.mesh)
        end
        m = Stepwise(1., sim.mesh)
        return new(name, sim, m, energy)
    end
end



struct EnergyCarrier <: AbstractCarrier
    name::String
    sim::Sim
    mass::Union{Nothing,Stepwise{Float64}}
    energy::Stepwise{Float64}

    @doc """
        EnergyCarrier(name::String, sim::Sim; energy=nothing)
    Return an EnergyCarrier with name `name` associated with Sim `sim`.
    Optional arguments:
    * energy: Number (or abstract vector of numbers, for each hour or step) describing the energy density in MWh/t.
    """
    function EnergyCarrier(name::String, sim::Sim; energy=nothing)
        if !isnothing(energy)
            en = _to_f64(energy)
            @argcheck all(en .> 0) "energy density must be strictly positive"
            _mass = Stepwise(1. ./ en, sim.mesh) # note the inversion
        else
            _mass = nothing
        end
        _energy = Stepwise(1., sim.mesh)
        return new(name, sim, _mass, _energy)
    end
end



struct CO2Carrier <: AbstractCarrier
    name::String
    sim::Sim
    mass::Stepwise{Float64}
    weight::Stepwise{Float64}

    @doc """
        CO2Carrier(name::String, sim::Sim; weight::Number=1.)
    Return a CO2Carrier with name `name` associated with Sim `sim`.
    Optional arguments:
        * weight: Number describing the CO2 equivalent weight in t CO2eq/t.
    """
    function CO2Carrier(name::String, sim::Sim; weight::Number=1.) 
        m = Stepwise(1., sim.mesh)
        return new(name, sim, m, Stepwise(_to_f64(weight), sim.mesh))
    end
end

sim(c::AbstractCarrier) = c.sim
name(c::AbstractCarrier) = c.name

Base.isequal(::AbstractCarrier, ::AbstractCarrier) = false
Base.isequal(c1::C, c2::C) where {C<:AbstractCarrier} = (c1 === c2)

# display carrier info
function Base.show(io::IO, c::AbstractCarrier)
    cn = modifiername(_defaultmodifier(carrierstyle(c)))
    print(
        io, 
        "Carrier \"$(name(c))\" for $cn"
    )
end
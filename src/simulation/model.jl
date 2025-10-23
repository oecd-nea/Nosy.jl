using JuMP, BilevelJuMP

# for a single-level mdodel, Lower and Upper levels are the same
Nosy.Lower(m::JuMP.Model) = m
Nosy.Upper(m::JuMP.Model) = m

_model(m::JuMP.Model) = m
_model(::BilevelJuMP.BilevelModel) = throw(AssertionError("Use lowermodel or uppermodel to access the models of a bilevel simulation."))
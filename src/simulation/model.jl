using JuMP, BilevelJuMP

# for a single-level mdodel, Lower and Upper levels are the same
Nosy.Lower(m::JuMP.Model) = m
Nosy.Upper(m::JuMP.Model) = m





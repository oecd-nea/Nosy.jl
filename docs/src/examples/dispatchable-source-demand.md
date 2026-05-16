# Dispatchable Source And Demand

This basic system has one electricity demand and one gas plant with optimisable
capacity, investment cost, and fuel cost.



```jldoctest dispatchable; output = false
using Nosy
using HiGHS
import JuMP: set_silent

# Generate a simulation with one JuMP model and one yearly hourly mesh.
s = Sim(Model(HiGHS.Optimizer); mesh=TimeMesh())
set_silent(model(s)) # silencing HiGHS REPL output

# Carrier
elec_carrier = EnergyCarrier("power", s)

# Synthetic data for load
hours = 1:8760
day_angle = 2pi .* ((hours .- 1) .% 24) ./ 24
season_angle = 2pi .* (hours .- 1) ./ 8760
load_profile = 3000 .+ 1500 .* sin.(day_angle .- pi / 2) .+
    120 .* sin.(season_angle .- pi / 2)

# Snapshot initialisation
snapshot = Snapshot(s)

# One electricity node. rule=:curtailed means production >= consumption.
grid = Node("grid", elec_carrier, rule=:curtailed)

# Component: electricity consumption from an exogenous demand profile.
consumption = Component("consumption", Demand(elec_carrier, load_profile))
connect!(snapshot, consumption, grid)

# Component: simplified gas plant, modelled as an infinitely flexible source.
# :capex and :fuel are user-defined cost tags, not reserved keywords.
gasplant = Component(
    "gasplant",
    DispatchableSource(elec_carrier), # Model archetype: dispatchable output flow
    [
        VariableCapacity("output", energy), # Optimised output capacity, in MW
        FixedCost(:capex, "output", energy, 60_000.0), # Annualised fixed cost, in EUR/MW
        VariableCost(:fuel, "output", energy, 50.0), # Fuel cost, in EUR/MWh
    ],
)
connect!(snapshot, gasplant, grid)

# Optimisation
optimize!(snapshot, cost(snapshot))
result = extract(snapshot) # Snapshot populated with the optimal solution

# output

Snapshot with 2 component(s) and 1 node(s)

```

Expected results:

```jldoctest dispatchable
julia> balance(result, "gasplant", :output, energy; collapse=false, aggregate=true)
8760-element Nosy.Hourly{Float64}:
 1380.0
 1431.11129143399
 1580.9620177936954
 1819.3401060284145
 2130.00049388116
 2491.7722040352337
 2880.001111231657
 3268.2300801626934
 3630.001975520575
 3940.6626720462264
    ⋮
 3940.6626720462273
 3630.0019755205753
 3268.2300801626934
 2880.001111231657
 2491.772204035234
 2130.00049388116
 1819.3401060284145
 1580.9620177936958
 1431.1112914339903

julia> cost(result)
1.5911999999999988e9

julia> cost(result, :capex)
2.772e8

julia> balance(result, "gasplant", :output, energy; collapse=true, aggregate=false)
Dict{String, Float64} with 1 entry:
  "output" => 2.628e7

julia> costs(result)
3×4 DataFrame
 Row │ component    capex    fuel     total
     │ String       Float64  Float64  Float64
─────┼─────────────────────────────────────────
   1 │ consumption  0.0      0.0      0.0
   2 │ gasplant     2.772e8  1.314e9  1.5912e9
   3 │ all          2.772e8  1.314e9  1.5912e9

julia> table(result, capacity)
1×2 DataFrame
 Row │ consumption  gasplant
     │ Float64      Float64
─────┼───────────────────────
   1 │         0.0    4620.0

julia> cost(snapshot, :capex)
60000 gasplant_output_energy_cap_

julia> table(snapshot, capacity)
1×2 DataFrame
 Row │ consumption  gasplant
     │ Float64      GenericA…
─────┼──────────────────────────────────────────
   1 │         0.0  gasplant_output_energy_cap_
```
With `collapse=false`, [`balance`](@ref) returns the hourly output time series;
with `collapse=true`, it returns the annual sum. The gas plant capacity is
exactly the annual load peak. Before extraction, the same metric calls can be
used on `snapshot`, but they return JuMP expressions instead of optimised
numeric values.

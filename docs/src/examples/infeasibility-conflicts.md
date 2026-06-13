# Infeasibility And Conflicts

This example makes the gas plant capacity upper bound too low. The model is
infeasible because demand cannot be covered during hours without PV output.

```julia
using Nosy
using HiGHS
import JuMP: set_silent

s = Sim(Model(HiGHS.Optimizer); mesh=TimeMesh())
set_silent(model(s))
elec_carrier = EnergyCarrier("power", s)

# Synthetic data for load
hours = 1:8760
day_angle = 2pi .* ((hours .- 1) .% 24) ./ 24
season_angle = 2pi .* (hours .- 1) ./ 8760
load_profile = 3000 .+ 1500 .* sin.(day_angle .- pi / 2) .+
    120 .* sin.(season_angle .- pi / 2)

# Synthetic data for PV
cf_pv = [
    x < 1e-6 ? 0.0 : x for x in [
        max(0, cos((h % 24 - 12) / 12 * pi) * (0.6 + 0.4 * sin(2pi * (h / 24) / 365)))
        for h in 1:8760
    ]
]

# Snapshot initialisation
snapshot = Snapshot(s)

# One electricity node
grid = Node("grid", elec_carrier, rule=:curtailed)

# Component: electricity consumption.
consumption = Component("consumption", Demand(elec_carrier, load_profile))
connect!(snapshot, consumption, grid)

# Component: PV.
pv = Component(
    "PV",
    ProfileSource(elec_carrier, cf_pv),
    [
        VariableCapacity("output", energy),
        FixedCost(:capex, "output", energy, 50_000.0),
    ],
)
connect!(snapshot, pv, grid)

# Component: gas turbine with limited capacity.
gasplant = Component(
    "gasplant",
    DispatchableSource(elec_carrier),
    [
        VariableCapacity("output", energy; ub=3_500.0), # Upper bound is too low.
        FixedCost(:capex, "output", energy, 60_000.0),
        VariableCost(:fuel, "output", energy, 50.0),
    ],
)
connect!(snapshot, gasplant, grid)

# Optimisation
optimize!(snapshot, cost(snapshot))
```

The model warns that the problem was not solved.
```julia
julia> result = extract(snapshot)
┌ Warning: System is not optimized. Termination status: INFEASIBLE. Returning the problem instead of the result.
```

Some solvers allow computing an IIS (irreducible infeasible subsystem) associated with the problem. When available, the IIS can be obtained so as to determine which constraints are conflicting. One very important remark is that the IIS is not unique, there may be multiple IIS associated with one problem, and repairing one IIS does not necessarily make the problem feasible.

```julia
julia> conflicts(result)
2-element Vector{JuMP.ConstraintRef}:
 gasplant_energy_out[4386] ≥ 3508.2277959647663
 gasplant_energy_out[4386] - gasplant_output_energy_cap_ ≤ 0
```

The result is easily interpretable: the gas plant energy output must be allowed to go at least above ~3505 MW, but the capacity is bound at 3500. Mathematically, we can calculate that the actual minimum value for the gas plant capacity is 3508.3 MW:

```julia
julia> maximum([iszero(cf_pv[i]) ?  load_profile[i] : 0. for i in eachindex(load_profile)]) # actual minimum capacity, for the whole year
3508.2277959647663
```

Below is a possible fix for the gas plant component. 

```julia
gasplant = Component(
    "gasplant",
    DispatchableSource(elec_carrier),
    [
        VariableCapacity("output", energy, ub=3509),
        FixedCost(:capex, "output", energy, 60000),
        VariableCost(:fuel, "output", energy, 50.),
    ]
)
```

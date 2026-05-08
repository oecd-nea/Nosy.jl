# PV And Battery Storage

This example combines one electricity demand, PV with variable capacity, and a
battery with variable power capacity and six hours of energy duration.



```jldoctest pv_battery; output = false
using Nosy
using HiGHS
import JuMP: set_silent

# Generate a simulation and carrier.
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

# One electricity node. evalprice=true stores the node dual prices after solve.
grid = Node("grid", elec_carrier, rule=:curtailed, evalprice=true)

# Component: electricity consumption.
consumption = Component("consumption", Demand(elec_carrier, load_profile))
connect!(snapshot, consumption, grid)

# Component: PV with optimised output capacity and fixed annualised cost.
pv = Component(
    "PV",
    ProfileSource(elec_carrier, cf_pv),
    [
        VariableCapacity("output", energy),
        FixedCost(:capex, "output", energy, 50_000.0),
    ],
)
connect!(snapshot, pv, grid)

# Component: battery storage.
battery = Component(
    "battery",
    BasicStorage(elec_carrier, elec_carrier, elec_carrier, energy; eff_i=0.85), # 85% roundtrip efficiency, modelled as input efficiency
    [
        VariableCapacity("input", energy), # Optimised charging capacity, in MW
        FixedCost(:capex, "input", energy, 50_000.0), # Annualised fixed cost, in EUR/MW
        Duration(6), # Six-hour storage duration linking flow and level capacities
    ],
)
connect!(snapshot, battery, grid) # Both input and output ports are connected.

# Optimisation
optimize!(snapshot, cost(snapshot))
result = extract(snapshot)

# output

Snapshot with 3 component(s) and 1 node(s)

```

Expected results:

```jldoctest pv_battery
julia> table(result, capacity)
1×3 DataFrame
 Row │ PV       battery  consumption
     │ Float64  Float64  Float64
─────┼───────────────────────────────
   1 │ 50373.4  5628.94          0.0

julia> p = dualprice(result.nodes["grid"]);

julia> minimum(p)
-0.0

julia> maximum(p)
3516.0807550572163

julia> sum(p) / length(p)
111.78592911234288
```
The capacity table shows the optimised PV and battery build-out. The dual price
is available because `evalprice=true` was set on the node and this is a
continuous optimisation problem. Dual prices are not available for MILP
problems because the dual is not defined for mixed-integer solutions.

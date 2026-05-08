# Two Power Nodes

This example has two electricity nodes connected by a unidirectional
transmission component. Selective `connect!` calls attach the input and output
ports to different nodes.

```jldoctest two_power_nodes; output = false
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

# Synthetic data for PV on the two nodes.
cf_pv1 = [
    x < 1e-6 ? 0.0 : x for x in [
        max(0, cos((h % 24 - 12) / 12 * pi) * (0.6 + 0.4 * sin(2pi * (h / 24) / 365)))
        for h in 1:8760
    ]
]
cf_pv2 = circshift(cf_pv1, 1) # Similar profile, shifted by one hour

# Snapshot initialisation
snapshot = Snapshot(s)

# Two electricity nodes.
grid1 = Node("grid1", elec_carrier, rule=:curtailed, evalprice=true)
grid2 = Node("grid2", elec_carrier, rule=:curtailed)

# Component: electricity consumption on grid1.
consumption = Component("consumption", Demand(elec_carrier, load_profile))
connect!(snapshot, consumption, grid1)

# Component: PV on grid1, with bounded optimised capacity.
pv1 = Component(
    "PV1",
    ProfileSource(elec_carrier, cf_pv1),
    [
        VariableCapacity("output", energy; lb=5_000.0, ub=10_000.0),
        FixedCost(:capex, "output", energy, 50_000.0),
    ],
)
connect!(snapshot, pv1, grid1)

# Component: PV on grid2.
pv2 = Component(
    "PV2",
    ProfileSource(elec_carrier, cf_pv2),
    [
        VariableCapacity("output", energy),
        FixedCost(:capex, "output", energy, 50_000.0),
    ],
)
connect!(snapshot, pv2, grid2)

# Component: battery storage connected on grid2.
battery = Component(
    "battery",
    BasicStorage(elec_carrier, elec_carrier, elec_carrier, energy; eff_i=0.85),
    [
        VariableCapacity("input", energy),
        FixedCost(:capex, "input", energy, 50_000.0),
        Duration(6),
    ],
)
connect!(snapshot, battery, grid2)

# Component: unidirectional transmission from grid2 to grid1.
transmission = Component(
    "transmission",
    BasicConverter(elec_carrier, elec_carrier), # No losses
    [FixedCapacity("input", energy, 8_000.0)], # Fixed capacity of 8000 MW
)
connect!(snapshot, transmission, grid2, "input") # Selective connection of input port
connect!(snapshot, transmission, grid1, "output") # Selective connection of output port

# Optimisation
optimize!(snapshot, cost(snapshot))
result = extract(snapshot)

# output

Snapshot with 5 component(s) and 2 node(s)

```

Expected result:

```jldoctest two_power_nodes
julia> table(result, capacity)
1×5 DataFrame
 Row │ PV1      PV2      battery  consumption  transmission
     │ Float64  Float64  Float64  Float64      Float64
─────┼──────────────────────────────────────────────────────
   1 │ 10000.0  40282.4  5491.59          0.0        8000.0
```
PV1 reaches its upper bound, while grid2 builds additional PV and storage and
exports through the transmission component.

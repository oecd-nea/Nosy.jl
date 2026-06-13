# Linked Capacities

Here the battery input capacity is defined as an affine expression of the PV
output capacity. The battery capacity is fixed to 50% of the PV capacity by
construction, without creating a second battery capacity variable.



```jldoctest linked_capacities; output = false
using Nosy
using HiGHS
import JuMP: set_silent

s = Sim(Model(HiGHS.Optimizer); mesh=TimeMesh())
set_silent(model(s))
elec_carrier = EnergyCarrier("power", s)

hours = 1:8760
day_angle = 2pi .* ((hours .- 1) .% 24) ./ 24
season_angle = 2pi .* (hours .- 1) ./ 8760
load_profile = 3000 .+ 1500 .* sin.(day_angle .- pi / 2) .+
    120 .* sin.(season_angle .- pi / 2)

cf_pv = [
    x < 1e-6 ? 0.0 : x for x in [
        max(0, cos((h % 24 - 12) / 12 * pi) * (0.6 + 0.4 * sin(2pi * (h / 24) / 365)))
        for h in 1:8760
    ]
]

snapshot = Snapshot(s)
grid = Node("grid", elec_carrier, rule=:curtailed)

consumption = Component("consumption", Demand(elec_carrier, load_profile))
connect!(snapshot, consumption, grid)

pv = Component(
    "PV",
    ProfileSource(elec_carrier, cf_pv),
    [
        VariableCapacity("output", energy),
        FixedCost(:capex, "output", energy, 50_000.0),
    ],
)
connect!(snapshot, pv, grid)

battery = Component(
    "battery",
    BasicStorage(elec_carrier, elec_carrier, elec_carrier, energy; eff_i=0.85),
    [
        VariableCapacity("input", energy; expression=0.5 * capacity(pv)),
        FixedCost(:capex, "input", energy, 50_000.0),
        Duration(6),
    ],
)
connect!(snapshot, battery, grid)

optimize!(snapshot, cost(snapshot))
result = extract(snapshot)

# output

Snapshot with 3 component(s) and 1 node(s)

```

Expected results:

```jldoctest linked_capacities
julia> table(result, capacity)
1×3 DataFrame
 Row │ PV       battery  consumption
     │ Float64  Float64  Float64
─────┼───────────────────────────────
   1 │ 46987.5  23493.7          0.0

julia> capacity(result, "battery") / capacity(result, "PV")
0.5
```
This pattern is useful in stochastic or multi-snapshot studies where several
assets must share the same investment decision.

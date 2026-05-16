# [Single-Level Vs Bilevel Capacity Expansion And Dispatch](@id bilevel-example)

Nosy supports bilevel optimisation through BilevelJuMP. The lower level can
represent system-operator dispatch while the upper level represents asset-owner
investment and dispatch decisions. The single-level benchmark below uses HiGHS;
the bilevel version uses Gurobi because this model is more computationally
intensive.

```jldoctest bilevel_single_level; output = false
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

# Snapshot initialisation
snapshot = Snapshot(s)
grid = Node("grid", elec_carrier, rule=:curtailed)

# Component: electricity consumption.
consumption = Component("consumption", Demand(elec_carrier, load_profile))
connect!(snapshot, consumption, grid)

# Component: user-owned dispatchable source with optimised capacity.
user_dispatchable = Component(
    "user_dispatchable",
    DispatchableSource(elec_carrier),
    [
        VariableCapacity("output", energy),
        FixedCost(:capex, "output", energy, 50_000.0),
        VariableCost(:dispatch, "output", energy, 45.0),
    ],
)
connect!(snapshot, user_dispatchable, grid)

# Component: user-owned intermittent source with optimised capacity.
cf_c = [
    x < 1e-6 ? 0.0 : x for x in [
        max(0, cos((h % 24 - 12) / 12 * pi) * (0.7 + 0.3 * sin(2pi * (h / 24) / 365)))
        for h in 1:8760
    ]
]
user_intermittent = Component(
    "user_intermittent",
    ProfileSource(elec_carrier, cf_c),
    [
        VariableCapacity("output", energy),
        FixedCost(:capex, "output", energy, 55_000.0),
    ],
)
connect!(snapshot, user_intermittent, grid)

# Component: other-owned dispatchable source with fixed capacity.
other_dispatchable = Component(
    "other_dispatchable",
    DispatchableSource(elec_carrier),
    [
        FixedCapacity("output", energy, 3_500.0),
        VariableCost(:dispatch, "output", energy, 25.0),
    ],
)
connect!(snapshot, other_dispatchable, grid)

# Single-level optimisation: minimise total system cost.
optimize!(snapshot, cost(snapshot))
result_s = extract(snapshot)

# output

Snapshot with 4 component(s) and 1 node(s)

```

The bilevel variant is a separate script.

```julia
using Nosy
using Gurobi
using BilevelJuMP: BilevelModel, IndicatorMode

function build_market_snapshot(s)
    elec_carrier = EnergyCarrier("power", s)

    # Synthetic data for load
    hours = 1:8760
    day_angle = 2pi .* ((hours .- 1) .% 24) ./ 24
    season_angle = 2pi .* (hours .- 1) ./ 8760
    load_profile = 3000 .+ 1500 .* sin.(day_angle .- pi / 2) .+
        120 .* sin.(season_angle .- pi / 2)

    # Snapshot initialisation
    snapshot = Snapshot(s)
    grid = Node("grid", elec_carrier, rule=:curtailed)

    # Component: electricity consumption.
    consumption = Component("consumption", Demand(elec_carrier, load_profile))
    connect!(snapshot, consumption, grid)

    # Component: user-owned dispatchable source with optimised capacity.
    user_dispatchable = Component(
        "user_dispatchable",
        DispatchableSource(elec_carrier),
        [
            VariableCapacity("output", energy),
            FixedCost(:capex, "output", energy, 50_000.0),
            VariableCost(:dispatch, "output", energy, 45.0),
        ],
    )
    connect!(snapshot, user_dispatchable, grid)

    # Component: user-owned intermittent source with optimised capacity.
    cf_c = [
        x < 1e-6 ? 0.0 : x for x in [
            max(0, cos((h % 24 - 12) / 12 * pi) * (0.7 + 0.3 * sin(2pi * (h / 24) / 365)))
            for h in 1:8760
        ]
    ]
    user_intermittent = Component(
        "user_intermittent",
        ProfileSource(elec_carrier, cf_c),
        [
            VariableCapacity("output", energy),
            FixedCost(:capex, "output", energy, 55_000.0),
        ],
    )
    connect!(snapshot, user_intermittent, grid)

    # Component: other-owned dispatchable source with fixed capacity.
    other_dispatchable = Component(
        "other_dispatchable",
        DispatchableSource(elec_carrier),
        [
            FixedCapacity("output", energy, 3_500.0),
            VariableCost(:dispatch, "output", energy, 25.0),
        ],
    )
    connect!(snapshot, other_dispatchable, grid)

    return snapshot
end

s = Sim(
    BilevelModel(
        Gurobi.Optimizer;
        mode=IndicatorMode(),
    );
    mesh=TimeMesh(),
)

snapshot = build_market_snapshot(s)

# Lower level: minimise operating cost for all producers.
# Upper level: minimise user investment cost plus user dispatch cost.
optimize!(
    snapshot,
    variablecost(snapshot),
    cost(snapshot, "user_dispatchable") + cost(snapshot, "user_intermittent"),
)
result_b = extract(snapshot)
```

Single-level expected results:

```jldoctest bilevel_single_level
julia> cost(result_s)
6.7586359241188e8

julia> cost(result_s, "user_dispatchable") + cost(result_s, "user_intermittent")
1.5692279376419443e8
```

Bilevel expected results:

```julia
julia> cost(result_b)
7.016918356637425e8

julia> cost(result_b, "user_dispatchable") + cost(result_b, "user_intermittent")
1.1410273417100954e8
```
The single-level solution has the lower total system cost. The bilevel solution
has a higher total cost, but lowers the user-owned asset cost because the upper
level optimises from that owner perspective.

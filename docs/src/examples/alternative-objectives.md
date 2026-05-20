# Alternative Objectives & near-optimal alternatives

The objective passed to [`optimize!`](@ref) can be any scalar expression built
from the snapshot. 

This example first minimises total cost, then maximises gas
capacity while keeping total cost within 1% of the optimum. 
This technique, sometimes referred to as Modelling to Generate Alternatives (MGA),
is used to discover near-optimal alternatives. If the alternative objective's value
if very different from its value as an optimization variable, it indicates a choice,
otherwise if they are similar it indicates a no-regrets decision.

```jldoctest alternative_objectives; output = false
using Nosy
using HiGHS
import JuMP: @constraint, set_silent # Avoid `using JuMP`; both JuMP and Nosy export optimize!.

function build_pv_gas_system()
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

    # Component: gas turbine.
    gasplant = Component(
        "gasplant",
        DispatchableSource(elec_carrier),
        [
            VariableCapacity("output", energy),
            FixedCost(:capex, "output", energy, 60_000.0),
            VariableCost(:fuel, "output", energy, 50.0),
        ],
    )
    connect!(snapshot, gasplant, grid)

    return snapshot
end

# First run: minimise total system cost.
cost_snapshot = build_pv_gas_system()
optimize!(cost_snapshot, cost(cost_snapshot))
cost_result = extract(cost_snapshot)
c0 = cost(cost_result) # Minimum system cost

# Second run: maximise gas capacity under a 1% system-cost slack.
snapshot = build_pv_gas_system()
s = sim(snapshot)
@constraint(model(s), cost(snapshot) <= c0 * 1.01)
optimize!(snapshot, -capacity(snapshot, "gasplant"))
result = extract(snapshot)

# output

Snapshot with 3 component(s) and 1 node(s)

```

The first run is the cost-optimal reference solution. In the second run:

  * gas plant capacity is maximised by minimising `-capacity(snapshot, "gasplant")`
  * total system cost is constrained to stay below `c0 * 1.01` using JuMP

Expected results:

```jldoctest alternative_objectives
julia> table(cost_result, capacity)
1×3 DataFrame
 Row │ PV       consumption  gasplant
     │ Float64  Float64      Float64
─────┼────────────────────────────────
   1 │ 6151.55          0.0   3508.23

julia> cost(result) / c0
1.0100000000000011

julia> table(result, capacity)
1×3 DataFrame
 Row │ PV       consumption  gasplant
     │ Float64  Float64      Float64
─────┼────────────────────────────────
   1 │ 6151.55          0.0    3733.8
```
The second solution spends the full 1% cost slack to increase gas capacity.
The optimisation objective passed to [`optimize!`](@ref) is flexible: it can be
any snapshot-derived scalar expression, including a JuMP expression or a number.

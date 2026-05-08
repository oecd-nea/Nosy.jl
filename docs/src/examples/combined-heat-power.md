# Combined Heat And Power

This example adds a combined heat and power (CHP) unit to a system with power
and heat demand. The CHP is a dispatchable heat source with free electricity
co-production. A [`VariableComposedCapacity`](@ref) constrains heat and
electricity under one optimised capacity, with weights 1 for heat and 3 for
electricity. A linked joint flow represents gas input and carries the fuel cost.
The power node is curtailed, so excess CHP or PV generation can be spilled.



```jldoctest chp; output = false
using Nosy
using HiGHS
import JuMP: set_silent

# Generate a simulation and carriers.
s = Sim(Model(HiGHS.Optimizer); mesh=TimeMesh())
set_silent(model(s))
elec_carrier = EnergyCarrier("power", s)
heat_carrier = EnergyCarrier("heat", s)
gas_carrier = EnergyCarrier("gas", s)

# Synthetic data for power demand, heat demand, and PV.
hours = 1:8760
day_angle = 2pi .* ((hours .- 1) .% 24) ./ 24
season_angle = 2pi .* (hours .- 1) ./ 8760

power_load = 2400 .+ 700 .* sin.(day_angle .- pi / 2) .+
    120 .* sin.(season_angle .- pi / 2)
heat_load = 900 .+ 550 .* sin.(season_angle .- pi / 2) .+
    120 .* sin.(day_angle .- pi / 2)

cf_pv = [
    x < 1e-6 ? 0.0 : x for x in [
        max(0, cos((h % 24 - 12) / 12 * pi) * (0.6 + 0.4 * sin(2pi * (h / 24) / 365)))
        for h in 1:8760
    ]
]

# Snapshot initialisation.
snapshot = Snapshot(s)

# One curtailed electricity node and one balanced heat node.
grid = Node("grid", elec_carrier, rule=:curtailed, evalprice=true)
heat_node = Node("heat", heat_carrier)

# Components: power and heat demand.
power_demand = Component("power demand", Demand(elec_carrier, power_load))
connect!(snapshot, power_demand, grid)

heat_demand = Component("heat demand", Demand(heat_carrier, heat_load))
connect!(snapshot, heat_demand, heat_node)

# Component: PV.
pv = Component(
    "PV",
    ProfileSource(elec_carrier, cf_pv),
    [
        VariableCapacity("output", energy),
        FixedCost(:capex, "output", energy, 45_000.0),
    ],
)
connect!(snapshot, pv, grid)

# Component: battery storage.
battery = Component(
    "battery",
    BasicStorage(elec_carrier, elec_carrier, elec_carrier, energy; eff_i=0.85),
    [
        VariableCapacity("input", energy),
        FixedCost(:capex, "input", energy, 45_000.0),
        Duration(4),
    ],
)
connect!(snapshot, battery, grid)

# Component: combined heat and power (CHP) with linked gas input.
chp = Component(
    "CHP",
    DispatchableSource(heat_carrier),
    [
        FreeJointFlow("power", elec_carrier, :output),
        # input gas as a joint flow of heat and power: gas = 0.9 * (heat + 1/0.3 * power)
        # this flow will not be connected to a node
        LinkedJointFlow(
            "gas",
            gas_carrier,
            :input,
            ("output", "power"),
            x -> 0.9 * (x[1] .+ 1/0.3 * x[2]);
            modifier=energy,
            mustconnect=false,
        ),
        VariableComposedCapacity(["output", "power"], energy; weights=[1.0, 3.0]),
        FixedCost(:capex, "output", energy, 35_000.0),
        VariableCost(:fuel, "gas", energy, 55.0),
    ],
)
connect!(snapshot, chp, heat_node, "output")
connect!(snapshot, chp, grid, "power")

# Optimisation
optimize!(snapshot, cost(snapshot))
result = extract(snapshot)

# output

Snapshot with 5 component(s) and 2 node(s)

```

Expected results:

```jldoctest chp
julia> table(result, capacity)
1×5 DataFrame
 Row │ CHP      PV       battery  heat demand  power demand
     │ Float64  Float64  Float64  Float64      Float64
─────┼──────────────────────────────────────────────────────
   1 │ 4485.28  19903.5  6464.37          0.0           0.0

julia> cost(result)
2.135348563904119e9

julia> chp_output = balance(result, "CHP", :output, energy; collapse=true, aggregate=false);

julia> chp_output["output"] # heat
7.883999999999987e6

julia> chp_output["power"]
2.4336509431618745e6

julia> balance(result, "CHP", :input, energy; collapse=true, aggregate=true)
1.4396552829485629e7
```
The heat output is exactly the annual heat demand. The CHP capacity is the
maximum value of `heat + 3 * power`, while the gas input is the flow that
receives the `:fuel` cost.

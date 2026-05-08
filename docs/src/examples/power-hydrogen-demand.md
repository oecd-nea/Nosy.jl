# Power And Hydrogen Demand

Hydrogen can be handled through both mass and energy modifiers. Here the
hydrogen carrier is a [`MassCarrier`](@ref) with an energy density of
33.33 MWh/t.

```jldoctest hydrogen_demand; output = false
using Nosy
using HiGHS
import JuMP: set_silent

# Generate a simulation and carriers.
s = Sim(Model(HiGHS.Optimizer); mesh=TimeMesh())
set_silent(model(s))
elec_carrier = EnergyCarrier("power", s)
h2_carrier = MassCarrier("hydrogen", s; energy=33.33) # H2 energy density, in MWh/t

# Synthetic data for load
hours = 1:8760
day_angle = 2pi .* ((hours .- 1) .% 24) ./ 24
season_angle = 2pi .* (hours .- 1) ./ 8760
load_profile = 3000 .+ 1500 .* sin.(day_angle .- pi / 2) .+
    120 .* sin.(season_angle .- pi / 2)

# Synthetic data for hydrogen demand and PV.
h2load = 10.0 # Tons per hour
cf_pv = [
    x < 1e-6 ? 0.0 : x for x in [
        max(0, cos((h % 24 - 12) / 12 * pi) * (0.6 + 0.4 * sin(2pi * (h / 24) / 365)))
        for h in 1:8760
    ]
]

# Snapshot initialisation
snapshot = Snapshot(s)

# One electricity node and one hydrogen node.
grid = Node("grid", elec_carrier, rule=:curtailed, evalprice=true)
h2_node = Node("hydrogen", h2_carrier, rule=:default, evalprice=true) # No H2 curtailment

# Component: electricity consumption.
consumption = Component("consumption", Demand(elec_carrier, load_profile))
connect!(snapshot, consumption, grid)

# Component: constant hydrogen demand.
h2_consumption = Component("H2 consumption", Demand(h2_carrier, h2load; modifier=mass))
connect!(snapshot, h2_consumption, h2_node)

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

# Component: PEM electrolyser converting electricity into hydrogen energy.
pem = Component(
    "PEM",
    BasicConverter(elec_carrier, h2_carrier; ratio=0.70, modifier=energy), # 70% conversion efficiency on energy
    [
        VariableCapacity("input", energy), # Electrical input capacity, in MW
        FixedCost(:capex, "input", energy, 60_000.0),
    ],
)
connect!(snapshot, pem, grid)
connect!(snapshot, pem, h2_node)

# Component: battery storage.
battery = Component(
    "battery",
    BasicStorage(elec_carrier, elec_carrier, elec_carrier, energy; eff_i=0.85),
    [
        VariableCapacity("input", energy),
        FixedCost(:capex, "input", energy, 50_000.0),
        Duration(6),
    ],
)
connect!(snapshot, battery, grid)

# Component: hydrogen storage with fixed level capacity and no cost.
h2storage = Component(
    "H2 storage",
    BasicStorage(h2_carrier, h2_carrier, h2_carrier, energy), # No losses
    [FixedCapacity("level", mass, h2load * 24 * 3)], # Three days of storage in the chosen level units
)
connect!(snapshot, h2storage, h2_node)

# Optimisation
optimize!(snapshot, cost(snapshot))
result = extract(snapshot)

# output

Snapshot with 6 component(s) and 2 node(s)

```

The capacities of the components in the cost-optimal solution are accessed as
before. Their meaning depends on how each component was built:

  * `H2 consumption`: hydrogen demand in t/h
  * `H2 storage`: maximum hydrogen level in t
  * `PEM`: electricity input capacity in MW
  * `PV`: electricity output capacity in MW
  * `battery`: electricity input capacity in MW
  * consumption components do not have capacity

Expected results:

```jldoctest hydrogen_demand
julia> table(result, capacity)
1×6 DataFrame
 Row │ H2 consumption  H2 storage  PEM      PV       battery  consumption 
     │ Float64         Float64     Float64  Float64  Float64  Float64     
─────┼────────────────────────────────────────────────────────────────────
   1 │            0.0       720.0  1120.84  56674.3  5784.46          0.0
   
julia> balance(result, "PEM", :output, mass; collapse=true, aggregate=true)
87599.99999999667

julia> balance(result, "PEM", :output, energy; collapse=true, aggregate=true)
2.919708000000001e6
```
The mass result is the annual hydrogen demand, 10 t/h for 8760 hours. The
energy result is the same hydrogen flow converted with the carrier energy
density.

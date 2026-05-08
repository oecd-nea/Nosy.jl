# PV, Battery, And Upward Reserve

Storage can provide upward reserve either by increasing discharge or by reducing
charging. This example forces a combined upward reserve requirement of 600 MW.

```jldoctest storage_reserve; output = false
using Nosy
using HiGHS
import JuMP: @constraint, set_silent # Avoid `using JuMP`; both JuMP and Nosy export optimize!.

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

# Component: battery with fixed capacities and ramping.
# ReserveUp on output with :up means more discharge.
# ReserveUp on input with :down means less charging.
battery = Component(
    "battery",
    BasicStorage(elec_carrier, elec_carrier, elec_carrier, energy; eff_i=0.85),
    [
        FixedCapacity("output", energy, 5_000.0),
        FixedCapacity("input", energy, 5_000.0),
        FixedCapacity("level", energy, 30_000.0),
        Ramping("output", :up, 5_000.0; modifier=energy),
        Ramping("output", :down, 5_000.0; modifier=energy),
        Ramping("input", :up, 5_000.0; modifier=energy),
        Ramping("input", :down, 5_000.0; modifier=energy),
        ReserveUp("reserve_up_discharge_15min", "output", :up, 0.25; modifier=energy),
        ReserveUp("reserve_up_charge_15min", "input", :down, 0.25; modifier=energy),
    ],
)
connect!(snapshot, battery, grid)

# Minimum combined upward reserve at node "grid" (600 MW per timestep).
@constraint(
    model(sim(snapshot)),
    reserve(snapshot, "grid", :up, "reserve_up_discharge_15min").data .+
    reserve(snapshot, "grid", :up, "reserve_up_charge_15min").data .>= 600.0,
)

# Optimisation
optimize!(snapshot, cost(snapshot))
result = extract(snapshot)

# output

Snapshot with 3 component(s) and 1 node(s)

```

When the level is high, discharge upward reserve often supplies the 600 MW.
When it is low, more reserve shifts to charge reduction. Only the battery
provides these reserves here, so totals at the grid match the battery.

```jldoctest storage_reserve
julia> balance(result, "battery", :level, energy, collapse=false, aggregate=true)
8760-element Nosy.Hourly{Float64}:
  8942.300011154877
  7536.744365437882
  6030.707710824039
  4330.556648912984
  2355.886348958197
     0.0
     0.0
   720.4430510088084
   150.0
   150.0
     ⋮
 19321.523156402218
 23340.120236061968
 23599.602275640373
 20525.4866799432
 17839.600022309754
 15528.713673351558
 13554.043373396771
 11853.892311485715
 10347.855656871872

julia> reserve(result, "battery", :up, "reserve_up_discharge_15min")
8760-element Nosy.Stepwise{Float64}:
 600.0
 600.0
 600.0
 600.0
 600.0
   0.0
   0.0
 600.0
 600.0
 600.0
   ⋮
 600.0
  55.52254037588318
 600.0
 600.0
 600.0
 600.0
 600.0
 600.0
 600.0

julia> reserve(result, "battery", :up, "reserve_up_charge_15min")
8760-element Nosy.Stepwise{Float64}:
   0.0
   0.0
   0.0
   0.0
   0.0
 600.0
 600.0
   0.0
   0.0
   0.0
   ⋮
   0.0
 544.4774596241168
   0.0
   0.0
   0.0
   0.0
   0.0
   0.0
   0.0
```
The battery can satisfy the same upward reserve requirement through different
physical actions depending on its state of charge.

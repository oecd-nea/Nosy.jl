# Operating Reserve

Reserve behaviors expose upward or downward reserve from dispatchable plants.
The minimum reserve requirement is added directly as a JuMP constraint.

```jldoctest operating_reserve; output = false
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

# Snapshot initialisation
snapshot = Snapshot(s)

# One electricity node
grid = Node("grid", elec_carrier, rule=:curtailed)

# Component: electricity consumption.
consumption = Component("consumption", Demand(elec_carrier, load_profile))
connect!(snapshot, consumption, grid)

# Component: gas plant with fixed capacity, ramping, and reserve capability.
gasplant = Component(
    "gasplant",
    DispatchableSource(elec_carrier),
    [
        FixedCapacity("output", energy, 2_000.0),
        Ramping("output", :up, 100.0; modifier=energy),
        Ramping("output", :down, 100.0; modifier=energy),
        VariableCost(:fuel, "output", energy, 50.0),
        ReserveUp("reserve_up_15min", "output", :up, 0.25; modifier=energy),
        ReserveDown("reserve_down_15min", "output", :down, 0.25; modifier=energy),
    ],
)
connect!(snapshot, gasplant, grid)

# Component: nuclear unit with fixed capacity, ramping, and reserve capability.
nuclear = Component(
    "nuclear",
    DispatchableSource(elec_carrier),
    [
        FixedCapacity("output", energy, 3_000.0),
        Ramping("output", :up, 50.0; modifier=energy),
        Ramping("output", :down, 50.0; modifier=energy),
        VariableCost(:dispatch, "output", energy, 10.0),
        ReserveUp("reserve_up_15min", "output", :up, 0.25; modifier=energy),
        ReserveDown("reserve_down_15min", "output", :down, 0.25; modifier=energy),
    ],
)
connect!(snapshot, nuclear, grid)

# Minimum reserve at node "grid": total up and total down >= 50 MW.
@constraint(model(sim(snapshot)), reserve(snapshot, "grid", :up, "reserve_up_15min").data .>= 50.0)
@constraint(model(sim(snapshot)), reserve(snapshot, "grid", :down, "reserve_down_15min").data .>= 50.0)

# Optimisation
optimize!(snapshot, cost(snapshot))
result = extract(snapshot)

# output

Snapshot with 3 component(s) and 1 node(s)

```

Reserve can be inspected at three levels: snapshot total, node total, and per
component. Upward reserve uses `rname` `"reserve_up_15min"` with sense `:up`;
downward reserve uses `"reserve_down_15min"` with sense `:down`.

  * `reserve(result, :up, "reserve_up_15min")` and `reserve(result, :down, "reserve_down_15min")` return totals over all components.
  * `reserve(result, "grid", :up, "reserve_up_15min")` returns total upward reserve at node `"grid"`, and similarly with `:down` and `"reserve_down_15min"`.
  * `reserve(result, "gasplant", :up, "reserve_up_15min")` and `reserve(result, "nuclear", :up, "reserve_up_15min")` return per-component reserve.

Upward reserve:

```jldoctest operating_reserve
julia> reserve(result, :up, "reserve_up_15min")
8760-element Nosy.Stepwise{Float64}:
 50.0
 50.0
 50.0
 50.0
 50.0
 50.0
 50.0
 50.0
 50.0
 50.0
  ⋮
 50.0
 50.0
 50.0
 50.0
 50.0
 50.0
 50.0
 50.0
 50.0

julia> reserve(result, "grid", :up, "reserve_up_15min")
8760-element Nosy.Stepwise{Float64}:
 50.0
 50.0
 50.0
 50.0
 50.0
 50.0
 50.0
 50.0
 50.0
 50.0
  ⋮
 50.0
 50.0
 50.0
 50.0
 50.0
 50.0
 50.0
 50.0
 50.0

julia> reserve(result, "gasplant", :up, "reserve_up_15min")
8760-element Nosy.Stepwise{Float64}:
  0.024142585324170796
  0.048285170647886844
  0.09657034129577369
  0.19314068259200212
  0.3862813651835495
  0.772562730367099
  1.5451254607346527
  3.0902509214693055
  6.180501842938611
 12.361003685876767
  ⋮
 50.0
 50.0
 50.0
 50.0
 50.0
 50.0
 50.0
 50.0
 50.0

julia> reserve(result, "nuclear", :up, "reserve_up_15min")
8760-element Nosy.Stepwise{Float64}:
 49.97585741467583
 49.95171482935211
 49.903429658704226
 49.806859317408
 49.61371863481645
 49.2274372696329
 48.45487453926535
 46.909749078530695
 43.81949815706139
 37.63899631412323
  ⋮
  0.0
  0.0
  0.0
  0.0
  0.0
  0.0
  0.0
  0.0
  0.0
```

Downward reserve follows the same pattern with `:down` and
`"reserve_down_15min"`: total and node reserves are 50 MW each step, while gas
and nuclear split the requirement depending on the timestep.

```jldoctest operating_reserve
julia> reserve(result, :down, "reserve_down_15min")
8760-element Nosy.Stepwise{Float64}:
 50.0
 50.0
 50.0
 50.0
 50.0
 50.0
 50.0
 50.0
 50.0
 50.0
  ⋮
 50.0
 50.0
 50.0
 50.0
 50.0
 50.0
 50.0
 50.0
 50.0

julia> reserve(result, "gasplant", :down, "reserve_down_15min")
8760-element Nosy.Stepwise{Float64}:
  0.0
 50.0
  0.0
  0.0
  0.0
  0.0
 50.0
 50.0
  0.0
  0.0
  ⋮
  0.0
  0.0
  0.0
  0.0
  0.0
  0.0
  0.0
  0.0
 49.975857414676284

julia> reserve(result, "nuclear", :down, "reserve_down_15min")
8760-element Nosy.Stepwise{Float64}:
 50.0
  0.0
 50.0
 50.0
 50.0
 50.0
  0.0
  0.0
 50.0
 50.0
  ⋮
 50.0
 50.0
 50.0
 50.0
 50.0
 50.0
 50.0
 50.0
  0.024142585323716048
```
The total reserve and node reserve meet the 50 MW requirement. Component-level
reserve shows how the requirement is split across eligible plants.

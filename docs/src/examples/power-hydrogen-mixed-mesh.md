# Power And Hydrogen With A Coarse Hydrogen Mesh

This example uses an hourly mesh for the power-side components and a coarser
mesh for the hydrogen node, hydrogen demand, and hydrogen storage. The
electrolyser remains an hourly component because its electricity input is
coupled to hourly VRE production. The hydrogen node balance is enforced on the
coarser hydrogen mesh.

The hydrogen mesh below uses 4-hour steps during the night and 2-hour steps
during the day. Balancing hydrogen over those intervals allows implicit
intra-interval shifting inside each hydrogen balance step.

```jldoctest mixed_mesh_hydrogen; output = false
using Nosy
using HiGHS
import JuMP: set_silent

# One-year study horizon with hourly power resolution.
power_mesh = TimeMesh(fill(1//1, 8760))

# The hydrogen mesh repeats each day: 4-hour steps at night and 2-hour
# steps during the day.
h2_day_mesh = vcat(fill(4//1, 2), fill(2//1, 6), [4//1])
h2_mesh = TimeMesh(repeat(h2_day_mesh, 365))

s = Sim(Model(HiGHS.Optimizer); mesh=power_mesh)
set_silent(model(s))

power = EnergyCarrier("power", s)
hydrogen = MassCarrier("hydrogen", s; energy=1.0)

# Hourly VRE profile: lower output at night, higher output during the day.
vre_profile = [
    h < 6 ? 0.45 :
    h < 8 ? 0.55 :
    h < 18 ? 0.85 :
    h < 20 ? 0.55 :
    0.45
    for h in (0:8759) .% 24
]

h2load = 3.15

snapshot = Snapshot(s)

grid = Node("grid", power, rule=:curtailed)
h2_node = Node("hydrogen", hydrogen; mesh=h2_mesh)

vre = Component(
    "VRE",
    ProfileSource(power, vre_profile; mesh=power_mesh),
    [
        VariableCapacity("output", energy),
        FixedCost(:capex, "output", energy, 1.0),
    ],
)
connect!(snapshot, vre, grid)

pem = Component(
    "PEM",
    BasicConverter(power, hydrogen; ratio=0.70, modifier=energy, mesh=power_mesh),
    [
        VariableCapacity("input", energy),
        FixedCost(:capex, "input", energy, 1.0),
    ],
)
connect!(snapshot, pem, grid)
connect!(snapshot, pem, h2_node)

h2_consumption = Component(
    "H2 consumption",
    Demand(hydrogen, h2load; modifier=mass, mesh=h2_mesh),
)
connect!(snapshot, h2_consumption, h2_node)

h2_storage = Component(
    "H2 storage",
    BasicStorage(hydrogen, hydrogen, hydrogen, mass; mesh=h2_mesh),
    [
        VariableCapacity("level", mass),
        FixedCost(:capex, "level", mass, 0.1),
    ],
)
connect!(snapshot, h2_storage, h2_node)

optimize!(snapshot, cost(snapshot))
result = extract(snapshot)

# output

Snapshot with 4 component(s) and 2 node(s)

```

The power components have 8760 hourly steps, while the hydrogen node, demand,
and storage have 9 coarser steps per day:

```jldoctest mixed_mesh_hydrogen
julia> Nosy.nsteps(power_mesh), Nosy.nsteps(h2_mesh)
(8760, 3285)
```

The cost-optimal result sizes VRE, the electrolyser input, and hydrogen storage:

```jldoctest mixed_mesh_hydrogen
julia> table(result, capacity)
1×4 DataFrame
 Row │ H2 consumption  H2 storage  PEM      VRE     
     │ Float64         Float64     Float64  Float64 
─────┼──────────────────────────────────────────────
   1 │            0.0     7.00461  6.03947  7.10526
```

The electrolyser still produces the same total hydrogen consumed over the
one-year horizon:

```jldoctest mixed_mesh_hydrogen
julia> balance(result, "PEM", :output, mass; collapse=true, aggregate=true)
27593.999999997308

julia> cost(result)
13.845197368421053
```

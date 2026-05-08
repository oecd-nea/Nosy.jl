# Getting Started

Nosy is a Julia package for building optimisation models of energy systems.
You provide a JuMP-compatible optimiser, create carriers and nodes, connect
components into a [`Snapshot`](@ref), optimize an objective, and extract a
solution snapshot for post-processing.

## Requirements

Nosy requires Julia 1.11 or newer and a LP or MILP solver compatible with
[JuMP](https://jump.dev/JuMP.jl/stable/). The examples in this documentation
use [HiGHS](https://highs.dev/) because it is open source and works well for
many linear examples. Other
[JuMP-compatible solvers](https://jump.dev/JuMP.jl/stable/installation/#Supported-solvers)
can be used by passing their optimiser constructor to [`Sim`](@ref).

## Minimal Workflow

```julia
using Nosy
using HiGHS

# Create a simulation with a HiGHS-backed JuMP model and the default hourly mesh.
s = Sim(Model(HiGHS.Optimizer); mesh=TimeMesh())
elec = EnergyCarrier("power", s)

# Create the system snapshot and one electricity node.
snapshot = Snapshot(s)
grid = Node("grid", elec, rule=:curtailed)

# Add an exogenous electricity demand.
load = fill(100.0, 8760)
consumption = Component("consumption", Demand(elec, load)) # consumption component made from the Demand model archetype
connect!(snapshot, consumption, grid)

# Add a dispatchable plant with optimisable capacity and operating cost.
plant = Component(
    "plant",
    DispatchableSource(elec), # DispatchableSource model archetype
    [
        VariableCapacity("output", energy), # variable output capacity (capacity of output is associated with a variable)
        FixedCost(:capex, "output", energy, 60_000.0), # variable output capacity is associated with a fixed cost
        VariableCost(:fuel, "output", energy, 50.0), # output flow is associated with a variable cost
    ],
)
connect!(snapshot, plant, grid)

# Minimise total system cost and extract the solved values.
optimize!(snapshot, cost(snapshot))
result = extract(snapshot)
```

The original `snapshot` contains JuMP variables and expressions. The extracted
`result` has the same structure, but is populated with optimal values when the
optimisation succeeds.

## Inspecting Results

```julia
# Total cost of the solved system.
cost(result)

# Cost breakdown by cost tag.
costs(result)

# Optimised component capacities.
table(result, capacity)

# Aggregated plant output over the model horizon.
balance(result, "plant", :output, energy; collapse=true, aggregate=true)
```
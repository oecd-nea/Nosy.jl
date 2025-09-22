# Nosy.jl
Nosy (the *Node systems* model) is a component-based energy system modelling and optimisation toolkit developed at the OECD Nuclear Energy Agency. It provides a reproducible workflow to describe energy networks, assemble optimisation models with JuMP, and analyse results through a rich post-processing layer.

## Highlights
- Compose systems from carriers, nodes, and components enriched with reusable behaviours (capacities, costs, ramping, unit commitment, joint flows).
- Work with flexible time discretisations via `TimeMesh`, `Stepwise`, and `Hourly` series; year-long hourly runs or clustered representative periods share the same API.
- Solve single-level or bilevel problems through JuMP and BilevelJuMP while staying solver-agnostic (HiGHS, CPLEX, Gurobi, etc.).
- Inspect solutions with built-in metrics: cost breakdowns, flow balances, marginal prices, dual values, and tabular summaries backed by DataFrames.
- Tag and query components or nodes to drive scenario dashboards and custom reporting without touching optimisation code.
- Designed for extension: add new behaviours, component archetypes, or post-processing helpers without rewriting the optimisation core.

## Getting Started

### Requirements
- Julia 1.11 or newer.
- A MathOptInterface-compatible solver (HiGHS is used in the examples below).

### Installation
Nosy.jl is not yet registered. Please ask NEA staff to obtain a copy: guillaume.krivtchik@oecd-nea.org.

### Quick Start
Avoid `using JuMP` directly because JuMP exports `optimize!`, which would shadow the method re-exported by Nosy. Instead, import the symbols you need:

```julia
using Nosy
using JuMP: Model, @constraint
using HiGHS

# Default TimeMesh() spans 8760 hourly steps
daycount_mesh = TimeMesh()
mysim = Sim(Model(HiGHS.Optimizer); mesh=daycount_mesh)

hours = collect(1:8760)
day_angle = 2pi .* ((hours .- 1) .% 24) ./ 24
season_angle = 2pi .* (hours .- 1) ./ 8760

# State-level demand profile (MW)
load_profile = 3000 .+ 1500 .* sin.(day_angle .- pi/2) .+ 120 .* sin.(season_angle .- pi/2)

# Per-unit renewable profile (0-1)
wind_profile = clamp.(0.45 .+ 0.1 .* sin.(season_angle) .+ 0.05 .* sin.(day_angle .+ pi/3), 0.05, 0.85)

# Carriers
elec_carrier = EnergyCarrier("power", mysim)
co2_carrier = CO2Carrier("co2", mysim)

snapshot = Snapshot(mysim)

grid = Node("grid", elec_carrier, rule=:curtailed, evalprice=true)
co2_sink = Node("co2_sink", co2_carrier, rule=:curtailed)

# Generation fleet capacity bounds (MW)
wind_capacity = 1800.0
nuclear_bounds = (lb=500.0, ub=5000.0)
gas_lb = 0.0
gas_emission_factor = 0.35  # tCO₂ per MWh

wind = Component(
    "wind",
    ProfileSource(elec_carrier, wind_profile),
    [
        FixedCapacity("output", energy, wind_capacity),
        FixedCost(:capex, "output", energy, 100000.0),
    ],
)
connect!(snapshot, wind, grid)

nuclear = Component(
    "nuclear",
    DispatchableSource(elec_carrier),
    [
        VariableCapacity("output", energy; lb=nuclear_bounds.lb, ub=nuclear_bounds.ub, unitsize=500.0),
        FixedCost(:capex, "output", energy, 400000.0),
        VariableCost(:fuel, "output", energy, 10.0),
    ],
)
connect!(snapshot, nuclear, grid)

gas = Component(
    "gas",
    DispatchableSource(elec_carrier),
    [
        VariableCapacity("output", energy; lb=gas_lb),
        FixedCost(:capex, "output", energy, 60000.0),
        VariableCost(:fuel, "output", energy, 40.0),
        LinkedJointFlow("co2", co2_carrier, :output, "output", x -> gas_emission_factor * x),
    ],
)
connect!(snapshot, gas, grid)
connect!(snapshot, gas, co2_sink)

load = Component(
    "load",
    Demand(elec_carrier, load_profile),
    [],
)
connect!(snapshot, load, grid)

# You can also directly add JuMP constraints
# Example: system-wide CO₂ intensity cap: 25 g/kWh = 0.025 t/MWh
co2_intensity_cap = 0.025
annual_emissions = balance(snapshot, "gas", :output, co2; collapse=true, aggregate=true)
annual_load = balance(snapshot, "load", :input, energy; collapse=true, aggregate=true)
@constraint(lowermodel(sim(snapshot)), annual_emissions <= co2_intensity_cap * annual_load)

# run the optimization and return result (populated with the optimal solution instead of symbolic expressions)
optimize!(snapshot, cost)
result = extract(snapshot)

emissions = flow(result, "gas", :output, co2)
demand = flow(result, "load", :input, energy)
intensity_g_per_kwh = emissions * 1000 / demand

println("Total system cost (EUR): ", cost(result))
println("Wind generation (MWh): ", flow(result, "wind", :output, energy))
println("Nuclear generation (MWh): ", flow(result, "nuclear", :output, energy))
println("Gas generation (MWh): ", flow(result, "gas", :output, energy))
println("CO₂ emissions (t): ", emissions)
println("System CO₂ intensity (g/kWh): ", intensity_g_per_kwh)
println("Day-1 hour-18 marginal price (EUR/MWh): ", dualprice(result.nodes["grid"])[18])
```

## Core Concepts
- **Simulation & time mesh** - `Sim` pairs a JuMP/BilevelJuMP model with a `TimeMesh`, exposing utilities such as `eachstep`, `nsteps`, or `nhours` for consistent temporal aggregation.
- **Carriers** - `MassCarrier`, `EnergyCarrier`, and `CO2Carrier` embed density conversions and default modifiers to keep units consistent across the system.
- **Components & behaviours** - Component archetypes (sources, sinks, converters, storage, transmission) are decorated with behaviours that add economics (costs), physics (ramping, duration), or discrete decisions (unit commitment, fleet sizing).
- **Joint flows & modifiers** - Behaviours can create additional flows (for example heat recovery or co-products) while enforcing carrier compatibility and modifier conversions.
- **Nodes & snapshots** - Nodes gather compatible flows, enforce balance constraints, track tags, and expose dual prices; snapshots collect interconnected components and nodes, ready for optimisation and extraction.
- **Metrics & tagging** - Utilities like `cost`, `variablecost`, `table`, and tagging helpers (`tag!`, `getcomponents`, `getnodes`) streamline scenario comparison and reporting pipelines.

## Optimisation Workflow
- Define a `Sim` with the desired solver and time mesh; reuse it across components sharing the same chronology.
- Instantiate carriers, component archetypes, and behaviours; keep domain-specific data in constructor arguments.
- Build a `Snapshot`, connect components to nodes, and call `optimize!` (single-level) or provide upper/lower metrics for bilevel problems.
- Inspect feasibility with `conflicts(sim)` when MILPs turn infeasible, or `finalize!(snapshot)` to review generated variables and constraints before solving.
- Call `extract(snapshot)` to replace symbolic expressions with Floats and enable downstream analytics.

## Diagnostics & Post-processing
- `cost(snapshot[, component][, type])` and `costs(snapshot)` (DataFrame) for economic breakdowns.
- `flow(snapshot, name, sense, modifier; hour/day/month)` and `balance(...)` to analyse timeseries at any aggregation level.
- `dualprice(node)` and `marginalprice(snapshot, nodename)` for nodal prices (requires a solver that exposes duals).
- `table(snapshot, metric)` to collect custom metrics across components or nodes.
- `conflicts(sim)` to retrieve an IIS from the underlying JuMP model when a solve fails.

## Testing
Run the package tests from the project root:

```julia
(Nosy) pkg> test
```

## Contributing
- Start with an issue or discussion describing the proposed change.
- Keep new behaviours or archetypes orthogonal; prefer composing them over editing existing ones when possible.
- Add targeted tests in `test/` and update the README or docs when user-facing features change.
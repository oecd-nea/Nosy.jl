# Nosy.jl

Nosy is a composable, component-based energy system modeling and optimization
toolkit developed at the OECD Nuclear Energy Agency. It provides a Julia
workflow to describe energy and commodity networks with LP and MILP
formulations, solve them through JuMP-compatible optimizers, and inspect the
resulting costs, capacities, flows, prices, and other metrics.

Nosy is used at the OECD NEA to model energy systems in the frame of system
cost studies, including:

- [Achieving Net Zero Carbon Emissions in Switzerland in 2050](https://www.oecd-nea.org/jcms/pl_74877/achieving-net-zero-carbon-emissions-in-switzerland-in-2050-low-carbon-scenarios-and-their-system-costs?details=true)
- [A Least-cost Capacity Mix to Satisfy Growing Electricity Demand without Carbon Emissions in Sweden](https://www.oecd-nea.org/jcms/pl_116142/a-least-cost-capacity-mix-to-satisfy-growing-electricity-demand-without-carbon-emissions-in-sweden)

## Documentation

The full documentation, including the user guide, API reference, and worked
examples, is available at:

<https://oecd-nea.github.io/Nosy.jl/dev/>

## Requirements

Nosy requires Julia 1.11 or newer and a LP or MILP solver compatible with
[JuMP](https://jump.dev/JuMP.jl/stable/). The example below uses
[HiGHS](https://highs.dev/), an open-source solver with a Julia wrapper
compatible with JuMP. Other
[JuMP-compatible solvers](https://jump.dev/JuMP.jl/stable/installation/#Supported-solvers)
can be used by passing their optimizer constructor to `Sim`.

## Core Ideas

Nosy keeps the modeling vocabulary compact:

- `Carrier`s describe what flows through the system, such as electricity,
  hydrogen, fuels, commodities, or CO2.
- `Node`s are accounting junctions where connected inflows and outflows are
  balanced.
- `Component`s are active technologies built from one model archetype, such as
  `DispatchableSource`, `ProfileSource`, `Demand`, `BasicConverter`, or
  `BasicStorage`.
- Behaviors refine components with common modeling features, such as fixed or
  variable capacities, fixed or variable costs, time-varying profiles, storage
  duration, or yearly flow constraints.
- A `Snapshot` contains the nodes and components to optimize, and can be
  extracted after optimization for result analysis.

More advanced features, including reserves, ramping, unit commitment, joint
flows, bilevel optimization, and conflict analysis, are covered in the
[documentation](https://oecd-nea.github.io/Nosy.jl/dev/).

## Basic Example

Nosy is unit-agnostic: values only need to be self-consistent. In the example
below, capacity is in MW, energy is in MWh, fixed cost is in currency per MW,
and variable cost is in currency per MWh.

```julia
using Nosy
using HiGHS

# Create a simulation with a JuMP model and the default hourly time mesh.
s = Sim(Model(HiGHS.Optimizer); mesh=TimeMesh())
elec = EnergyCarrier("power", s)

# Create one snapshot and one electricity node.
snapshot = Snapshot(s)
grid = Node("grid", elec, rule=:curtailed)

# Add an exogenous electricity demand.
load = fill(100.0, 8760)
demand = Component("demand", Demand(elec, load))
connect!(snapshot, demand, grid)

# Add a dispatchable source with optimizable capacity and operating cost.
plant = Component(
    "plant",
    DispatchableSource(elec),
    [
        VariableCapacity("output", energy),
        FixedCost(:capex, "output", energy, 60_000.0),
        VariableCost(:fuel, "output", energy, 50.0),
    ],
)
connect!(snapshot, plant, grid)

# Minimize total system cost and extract the solved values.
optimize!(snapshot, cost(snapshot))
result = extract(snapshot)

# Inspect results.
cost(result)
capacity(result, "plant")
balance(result, "plant", :output, energy; collapse=true, aggregate=true)
```

## Related Model: POSY2

POSY2 is a country- and regional-level power systems model developed at the NEA
on top of Nosy, currently planned for open-source release. Where Nosy exposes
the building blocks directly, POSY2 adds a higher-level layer targeting energy
analysts who are not optimization modelers.

## License

This project is licensed under the [MIT License](LICENSE.md).

## Authors

- Guillaume KRIVTCHIK, OECD Nuclear Energy Agency (main author)
- Yuri BAE, Korea Institute of Energy Technology

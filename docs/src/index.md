# Introduction

[Nosy.jl](https://github.com/oecd-nea/Nosy.jl) is a composable,
component-based energy system modelling and optimisation toolkit developed at
the [OECD Nuclear Energy Agency](https://oecd-nea.org/). It provides a Julia
workflow for describing energy and commodities networks with LP and MILP
formulations, solving them through JuMP-compatible optimisers, and inspecting
the resulting costs, capacities, flows, prices and other characteristics.

The central idea is composition. A component starts with a compact model
archetype, such as a dispatchable source, profile source, converter, storage
unit, sink, demand, or line. Behaviors then refine that archetype with
capacities, costs, ramping, unit commitment, yearly sums, reserve provision, or
joint flows. This keeps the model vocabulary small while still covering a wide
range of technologies.

## Key capabilities

- Build systems using composable components at any level of detail.
- Model electricity, hydrogen, fuels, commodities, and CO2.
- Stay solver-agnostic through [JuMP](https://jump.dev/JuMP.jl/stable/).
- Query flows and built-in metrics for capacity, cost, reserve, price etc.

## Licence

Nosy is available under the MIT licence.
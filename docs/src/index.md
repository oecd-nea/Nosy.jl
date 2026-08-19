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

## Higher-level modelling with Posy2.jl

[Posy2.jl](https://github.com/oecd-nea/Posy2.jl) builds on Nosy with
standard technology constructors, input-data workflows, multi-zone power
system modelling, and energy-system reporting. Posy2 components remain
ordinary Nosy components, so studies can still be extended directly with
Nosy's compositional API. See the
[Posy2.jl manual](https://oecd-nea.github.io/Posy2.jl/dev/).

## Licence

Nosy is available under the MIT licence.
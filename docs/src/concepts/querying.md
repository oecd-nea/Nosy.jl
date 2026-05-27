# Querying And Optimizing

This page covers the calls used once a snapshot exists: balance queries, metrics and tables, and optimization objectives.

## Balance

[`balance`](@ref) queries flows over the full simulation horizon. It can be
called on a component, a node, or a snapshot name. The `sense` argument chooses
which side to inspect:

- `:input` for incoming flows.
- `:output` for outgoing flows.
- `:level` for storage levels, on components that have level ports.

The modifier argument chooses the physical view: [`energy`](@ref),
[`mass`](@ref), or [`co2`](@ref). The same port can be queried with different
modifiers when its carrier supports them.

Examples:

```julia
# Total yearly electricity produced by a component.
balance(result, "gasplant", :output, energy; collapse=true, aggregate=true)

# Hourly electricity output of each output port of a component.
balance(result, "gasplant", :output, energy; collapse=false, aggregate=false)

# Hourly aggregate electricity input to a node.
balance(result, "grid", :input, energy; collapse=false, aggregate=true)

# Storage level time series. Levels cannot be collapsed over time.
balance(result, "battery", :level, energy; collapse=false, aggregate=true)
```

For a carrier with both mass and energy views, use the modifier to choose the
unit of the same port. For example, if `PEM` produces hydrogen with
`MassCarrier("hydrogen", s; energy=33.33)`, the output can be read in tons or
in MWh:

```julia
balance(result, "PEM", :output, mass; collapse=true, aggregate=true)
balance(result, "PEM", :output, energy; collapse=true, aggregate=true)
```

Use `aggregate=false` to keep separate ports or connected components instead
of summing them together:

```julia
balance(result, "PEM", :output, mass; collapse=true, aggregate=false)
balance(result, "hydrogen", :input, mass; collapse=false, aggregate=false)
```

## Metrics And Tables

A metric is a query function that turns a component, node, or snapshot into a
number, expression, vector, or dictionary that can be used for reporting or as
part of another optimisation expression. Metrics work both before and after
optimisation: before extraction they usually return JuMP expressions; after
extraction they return numeric values.

Common metrics include:

- [`capacity`](@ref): installed or optimised capacity.
- [`nbunits`](@ref): number of units when a capacity behavior uses a unit size.
- [`cost`](@ref), [`fixedcost`](@ref), [`constantcost`](@ref),
  [`variablecost`](@ref), [`noloadcost`](@ref), and [`startupcost`](@ref):
  total or tagged cost terms.
- [`reserve`](@ref): reserve available at snapshot, node, or component level.

Examples:

```julia
capacity(result, "gasplant")
cost(result, :fuel)
reserve(result, "grid", :up, "reserve_up_15min")
```

A table is a DataFrames-based summary that evaluates a metric across several
components or cost tags. Tables are meant for quick reporting, inspection, and
scenario dashboards.

Examples:

```julia
table(result, capacity)
table(result, reserve)
costs(result)
```

`table(result, capacity)` returns one row with one column per component.
`costs(result)` returns a cost breakdown by component and cost tag, including
an `all` row for system totals.

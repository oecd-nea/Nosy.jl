# Nosy.jl

Nosy is a component-based energy system modeling and optimization toolkit developed at the OECD Nuclear Energy Agency. It provides a workflow to describe energy networks using the LP / MILP formalism, and analyze the results. It can be used directly, or as a library to develop higher-level models.

Nosy is used at the OECD NEA to model energy systems in the frame of System costs studies.
System cost studies at the NEA include:
  * [Achieving Net Zero Carbon Emissions in Switzerland in 2050](https://www.oecd-nea.org/jcms/pl_74877/achieving-net-zero-carbon-emissions-in-switzerland-in-2050-low-carbon-scenarios-and-their-system-costs?details=true)
  * [A Least-cost Capacity Mix to Satisfy Growing Electricity Demand without Carbon Emissions in Sweden](https://www.oecd-nea.org/jcms/pl_116142/a-least-cost-capacity-mix-to-satisfy-growing-electricity-demand-without-carbon-emissions-in-sweden)

License is MIT.

## Highlights
- Compose systems from carriers, nodes, and components enriched with reusable behaviors (capacities, costs, ramping, unit commitment, joint flows, operational reserves).
- Model multiple electricity nodes, hydrogen, fuels, commodities with automatic conversions.
- Work with flexible time discretization.
- Solve problems through JuMP while staying solver-agnostic (HiGHS, Gurobi etc.).
- Inspect solutions with built-in metrics: cost breakdowns, capacities, flow balances, prices, and tabular summaries.
- Tag and query components or nodes to drive scenario dashboards and custom reporting.

## Requirements
Nosy requires a LP/MILP solver compatible with [JuMP](https://jump.dev/JuMP.jl/stable/).
In the examples below we use [HiGHS](https://highs.dev/) which is open-source and has a [Julia wrapper](https://ergo-code.github.io/HiGHS/dev/interfaces/julia/) compatible with JuMP. List of LP/MILP solvers compatible with JuMP can be found [here](https://jump.dev/JuMP.jl/stable/installation/#Supported-solvers).


## Available tools

The list of model archetypes, behaviors, joint flows, modifiers and metrics is defined below.

All functions exported by Nosy are supported with a docstring accessible using the `?`character for help mode.

```julia
help? VariableCapacity
  VariableCapacity(pname::String, modifier::Function; lb::Number=0., ub::Number=Inf, unitsize::Union{Nothing,Number}, integer::Bool)

  Return a VariableCapacity behavior data, associated with port name `pname` and modifier `modifier`. Optional parameters:

    •  lb: lower bound
    •  ub: upper bound
    •  unitsize: size of the unit when considering a fleet
    •  integer: i⁠f unitsize is a number, constrains the number of units to be integer
```

The philosophy of Nosy is:
  * maintain a minimal number of model archetypes
  * refine components using as many behaviors and joint flows as required

### Components, nodes and snapshots
The `Component`s are the active parts of the system. Components emit and/or consume flows, and can have a level. `Component`s are generated ad hoc, from the combination of one model archetype plus any number of behaviors and joint flows defined below. 

The `Node`s are the passive parts of the system. A `Node` is a point where flows converge, split, are produced or consumed. Nodes are the accounting junctions where energy or mass are tracked. For instance, the "supply is equal to demand" rule is applied at the level of `Node`s. By default, at each hour, the sum of the input flows of a node is equal to the sum of the output flows of a node.
Nodes and components must be connected together. A component is only connected to nodes, and nodes are only connected to components. 


The `Snapshot` is the system in which all components and nodes live, and is generally optimized by Nosy.


### Model archetypes
Nosy has a small list of model archetypes that define the most basic functions of the component. Model archetype are:
  * `DispatchableSource`: flexibly generates an output flow (ex: gas plant)
  * `ProfileSource`: generates an output flow following an exogenous profile (ex: wind turbine)
  * `Demand`: consumes an input flow following an exogenous pattern (ex: final consumption)
  * `BasicSink`: flexibly consumes an input flow (ex: flexible consumption)
  * `BasicConverter`: converts an input flow into an output flow (ex: hydrogen turbine with model of hydrogen input flow)
  * `BasicStorage`: converts a flexible input flow into a flexible output flow and a level (ex: battery storage)
  * `LazyStorage`: converts any input flow into any output flow and a level (ex: hydro reservoir)
  * `ACLine` and `DCLine`: AC and DC power lines, required for the DC-OPF formalism.

### Behaviors
Behaviors refine how the component operates, beyond the model archetypes. Most common behaviors are:
  * `FixedCapacity`: set the capacity of a model port to a numeric value
  * `VariableCapacity`: set the capacity of a model port to a variable value
  * `CapacityMultiplier`: refines the capacity behaviors by adding time-dependent modification of the capacity
  * `Duration`: set a relationship between the input, output and level capacity of a component associated with a level
  * `YearlySum`: constrain the sum of the flow of a port to a numeric value
  * `Ramping`: constrain the variation of the flow of a port to be below a numeric value at every timestep (up or down)
  * `ReserveUp`: constrain upward reserve on a port (increased discharge or reduced charging) by headroom, ramping, and storage energy limits
  * `ReserveDown`: constrain downward reserve on a port (reduced discharge or increased charging) by headroom, ramping, and storage energy limits
  * `UnitCommitment`: assign unit commitment characteristics (min ratio, min uptime, min downtime, startup duration, shutdown duration, linear/integer commitment) to the flow of a port

Costs also are modeled as behaviors:
  * `FixedCost`: add a cost related to capacity
  * `VariableCost`: add a cost related to flow
  * `StartupCost`: add a cost related to startup
  * `NoLoadCost`: add a no-load cost

### Joint flows
Joint flows add additional flows to the component (in addition to the model archetype's flows). Joint flows are:
  * `FixedJointFlow`: an exogenously defined flow
  * `FreeJointFlow`: an infinitely flexible flow
  * `LinkedJointFlow`: a flow that can be expressed as a function of other flows of the component

### Metrics
Metrics are functions that can be applied to a `Component` or a `Snapshot` and return a scalar. The metrics detailed below are available.
  * `capacity`
  * `nbunits`
  * `cost`
  * `fixedcost`
  * `variablecost`
  * `noloadcost`
  * `startupcost`

NB most of these metrics can use additional arguments to modify the evaluation. For instance, all the cost metrics accept a `type::Symbol` optional argument that is a tag defined when instantiating cost behaviors.


### Modifiers
Every flow is associated with a carrier type (e.g. `MassCarrier`, `EnergyCarrier` etc.). Modifiers help manipulating multiple aspects of a single `Carrier`. For instance, H2 can be viewed either through its mass (t) or energy (MWh). Each carrier has a default modifier used as a fallback if no modifier is specified.
  * `energy` (default modifier for `EnergyCarrier`)
  * `mass` (default modifier for `MassCarrier`, `CO2Carrier`)
  * `co2`
  * `defaultmodifier` (used as a fallback if modifier is not specified, not exported)


### Balances
Flows going in and out of components and nodes can be evaluated using the following functions:
  * `balance`: return the flow going in or out of a component or a node, with filters on sense and modifier, as well as options for aggregating flows together and returning time series or yearly sums.
  * `flow`: return the flow going in or out of a component or a node, with filters on sense and modifier, at a given hour.

### Note on time modeling
  * Nosy uses a `TimeMesh` letting the user deciding the duration of timesteps. The default `TimeMesh` is 8760 hours. Under the hood, Nosy is able to work with rational fractions of time, however the hourly values are returned to the user.
  * A `TimeMesh` is expected to represent a full year, whether or not it contains 8760 hours.
  * For one given `Snapshot`, time is considered as cyclical (the hour after the last hour is the first hour). This design choice was made to improve the fidelity of technical behaviors.
  * `balance` returns `Hourly` vectors, which is a custom circular array for which `h[n] == h[n+8760]`. Any integer index of a `Hourly` vector can be queried.

## Examples

Nosy is unit-agnostic, the user decides the actual units of any value - the only constraint is self-consistency. For the examples below, we will assume the following units:
  * Power, capacity: MW
  * Energy: MWh
  * Fixed costs: €/MW
  * Variable costs: €/MWh
  * Masses including CO2: tons

Please note that the examples are run in the REPL for the sake of simplicity, but it is generally advised to use functions instead.

### Example 1.1: Dispatchable source and demand

In this example, we build a simple system with:
  * one electricity demand (with a profile)
  * one gas plant component, with a variable (optimizable) capacity, investment cost and fuel cost

```julia
using Nosy
using HiGHS

# Generate a Simulation (solver, basic data shared with all components and nodes)
s = Sim(Model(HiGHS.Optimizer); mesh=TimeMesh()) # default TimeMesh() spans 8760 hourly steps

# Carriers
elec_carrier = EnergyCarrier("power", s)

# Synthetic data for load
hours = 1:8760
day_angle = 2pi .* ((hours .- 1) .% 24) ./ 24
season_angle = 2pi .* (hours .- 1) ./ 8760
load_profile = 3000 .+ 1500 .* sin.(day_angle .- pi/2) .+ 120 .* sin.(season_angle .- pi/2) # State-level demand profile (MW)

# Snapshot initialization
snapshot = Snapshot(s)

# One electricity node
grid = Node("grid", elec_carrier, rule=:curtailed) # rule=:curtailed implies production >= consumption at each hour on this node

# Component: Electricity consumption, which is based on the "Demand" archetype, and no specific behaviors
# Its input is an exogenous time series (load_profile)
consumption = Component(
    "consumption",
    Demand(elec_carrier, load_profile),
)
connect!(snapshot, consumption, grid) # connect the consumption component to the grid. If a component is not connected, it is not taken into account in the optimization.

# Component: simplified gas plant, modeled here as an infinitely flexible dispatchable source
# Its capacity is an optimization variable
# Its electricity generation is a set of optimization variables
# NB :capex and :fuel are not reserved keywords, they are tags decided by the user
gasplant = Component(
    "gasplant",
    DispatchableSource(elec_carrier), # Model archetype: infinitely dispatchable source
    # below is a vector of behaviors that will refine the component
    [
        VariableCapacity("output", energy), # Behavior: variable capacity associated with the output of the gas plant # in MW
        FixedCost(:capex, "output", energy, 60000), # Behavior: annualized fixed cost, tagged as capex, associated with the capacity of the output of the gas plant (in €/MW)
        VariableCost(:fuel, "output", energy, 50.) # Behavior: variable cost, tagged as fuel cost, associated with the output of the gas plant
    ]
)
connect!(snapshot, gasplant, grid) # connect the gas plant to the grid

# Optimization
optimize!(snapshot, cost) # optimize the problem using the cost of the full snapshot as the objective
result = extract(snapshot) # return a snapshot populated with the optimal solution
```

The `snapshot` and `result` are almost the same object, except `snapshot` is populated with variables and `result` is populated with the optimal solution.

The `result` can be post-processed using various functions.

The `balance` function, when used with `collapse=false`, returns the time series associated with the component at each hour.
It must be used together with a "modifier" (here: `energy`) that indicates which aspect of the carrier we analyze. Here, we look at the (electric) energy, therefore we use the modifier `energy`.
```julia
julia> balance(result, "gasplant", :output, energy, collapse=false, aggregate=true) # output energy balance of the gas plant at every hour
8760-element Nosy.Hourly{Float64}:
 1380.0
 1431.11129143399
 1580.9620177936954
 1819.3401060284145
 2130.00049388116
 2491.7722040352337
    ⋮
 2880.001111231657
 2491.772204035234
 2130.00049388116
 1819.3401060284145
 1580.9620177936958
 1431.1112914339903
```

Conversely, you can use the same function to return the annual sum of the time series.
```julia
julia> balance(result, "gasplant", :output, energy, collapse=true, aggregate=false)
Dict{String, Float64} with 1 entry:
  "output" => 2.628e7
```

The `cost` function returns the total cost associated with the snapshot.

```julia
julia> cost(result)
1.5911999999999988e9 # €
```

You can evaluate partial costs.

```julia
julia> cost(result, :capex)
2.772e8
```

You can inspect the `snapshot` the same way you would inspect the `result`. But instead, the metrics values are expressed using the problem variables.
```julia
julia> cost(snapshot, :capex)
60000 gasplant_output_energy_cap
```

The `costs` function returns a table of all costs.
```julia
julia> costs(result)
3×4 DataFrame
 Row │ component    capex    fuel     total    
     │ String       Float64  Float64  Float64
─────┼─────────────────────────────────────────
   1 │ consumption  0.0      0.0      0.0
   2 │ gasplant     2.772e8  1.314e9  1.5912e9
   3 │ all          2.772e8  1.314e9  1.5912e9
```

Metrics (functions applied to components to return a scalar) can be applied to all components in the system using the `table` function.
```julia
julia> table(result, capacity)
1×2 DataFrame
 Row │ consumption  gasplant 
     │ Float64      Float64
─────┼────────────────────────
   1 │         0.0     4620.0

julia> table(snapshot, capacity)
1×2 DataFrame
 Row │ consumption  gasplant                   
     │ GenericAff…  GenericAff…
─────┼──────────────────────────────────────────
   1 │ 0            gasplant_output_energy_cap
```


### Example 1.2: Dispatchable source with CO2 emissions and demand and CO2 tax

In this example, we refine the example above to add CO2 emissions and a CO2 tax.

```julia
using Nosy
using HiGHS

s = Sim(Model(HiGHS.Optimizer); mesh=TimeMesh())

elec_carrier = EnergyCarrier("power", s)
co2_carrier = CO2Carrier("co2", s)

# Synthetic data for load
hours = 1:8760
day_angle = 2pi .* ((hours .- 1) .% 24) ./ 24
season_angle = 2pi .* (hours .- 1) ./ 8760
load_profile = 3000 .+ 1500 .* sin.(day_angle .- pi/2) .+ 120 .* sin.(season_angle .- pi/2)

# Snapshot initialization
snapshot = Snapshot(s)

# One electricity node and one CO2 node
grid = Node("grid", elec_carrier, rule=:curtailed)
co2_node = Node("co2", co2_carrier, rule=:curtailed)

# Component: Electricity consumption
consumption = Component(
    "consumption",
    Demand(elec_carrier, load_profile),
)
connect!(snapshot, consumption, grid)

# Component: simplified gas plant, modeled here as an infinitely flexible dispatchable source with CO2 emissions
# Its capacity is an optimization variable
# Its electricity generation is a set of optimization variables
# It emits 400gCO2/KWh of electricity
# NB :capex and :fuel are not reserved keywords, they are tags decided by the user
gasplant = Component(
    "gasplant",
    DispatchableSource(elec_carrier),
    [
        VariableCapacity("output", energy),
        FixedCost(:capex, "output", energy, 60000),
        VariableCost(:fuel, "output", energy, 50.),
        LinkedJointFlow("co2", co2_carrier, :output, "output", x->0.400*x[1]), # 0.4 tCO2/MWh of energy (electricity) coming out of the gas plant
        VariableCost(:co2tax, "co2", co2, 100.), # the co2 joint flow is treated as a dedicated port for costing. Add a carbon tax of 100 €/t of CO2 emitted by the plant. Modifier is co2.
    ]
)
connect!(snapshot, gasplant, grid) # connect the gas plant to the grid
connect!(snapshot, gasplant, co2_node) # connect the gas plant to the CO2 node

# Optimization
optimize!(snapshot, cost)
result = extract(snapshot)
```

The table of costs of the new solution is:
```julia
julia> costs(result)
3×5 DataFrame
 Row │ component    capex    co2tax    fuel     total    
     │ String       Float64  Float64   Float64  Float64
─────┼───────────────────────────────────────────────────
   1 │ consumption  0.0      0.0       0.0      0.0
   2 │ gasplant     2.772e8  1.0512e9  1.314e9  2.6424e9
   3 │ all          2.772e8  1.0512e9  1.314e9  2.6424e9
```

To get the CO2 emitted over the year by the gas plant is (in tons), we will perform a balance, this time using the `co2` modifier.
We could also have used the `mass` modifier (CO2Carrier has both `co2` and `mass` modifiers, which yield the same result for equivalent CO2).
```julia
julia> balance(result, "gasplant", :output, co2, collapse=true, aggregate=true)
1.0512000000000114e7

julia> balance(result, "gasplant", :output, mass, collapse=true, aggregate=true)
1.0512000000000114e7
```


### Example 2.1: PV and battery storage

In this example, we build a simple system with:
  * one electricity demand (with a profile)
  * one PV component, with a variable capacity and an investment cost
  * one battery storage component, with a variable capacity and a duration of 6h

```julia
using Nosy
using HiGHS

s = Sim(Model(HiGHS.Optimizer); mesh=TimeMesh())

elec_carrier = EnergyCarrier("power", s)

# Synthetic data for load
hours = 1:8760
day_angle = 2pi .* ((hours .- 1) .% 24) ./ 24
season_angle = 2pi .* (hours .- 1) ./ 8760
load_profile = 3000 .+ 1500 .* sin.(day_angle .- pi/2) .+ 120 .* sin.(season_angle .- pi/2)

# Synthetic data for PV
cf_pv = [x < 1e-6 ? 0.0 : x for x in [max(0, cos((h%24 - 12)/12*pi) * (0.6 + 0.4*sin(2*pi*(h/24)/365))) for h in 1:8760]]

# Snapshot initialization
snapshot = Snapshot(s)

# One electricity node
grid = Node("grid", elec_carrier, rule=:curtailed, evalprice=true)

# Component: Electricity consumption
consumption = Component(
    "consumption",
    Demand(elec_carrier, load_profile),
)
connect!(snapshot, consumption, grid)

# Component: PV
pv = Component(
    "PV",
    ProfileSource(elec_carrier, cf_pv),
    [
        VariableCapacity("output", energy),
        FixedCost(:capex, "output", energy, 50000),
    ]
)
connect!(snapshot, pv, grid)

# Component: battery storage
battery = Component(
    "battery",
    BasicStorage(elec_carrier, elec_carrier, elec_carrier, energy, eff_i=0.85), # Battery storage with 85% roundtrip efficiency
    [
        VariableCapacity("input", energy), # Behavior: variable capacity associated with the input of the battery # in MW
        FixedCost(:capex, "input", energy, 50000), # Behavior: annualized fixed cost, tagged as capex, associated with the capacity of the input of the battery (in €/MW)
        Duration(6), # Behavior: battery duration is 6 hours (i.e. level capacity = 6 * input capacity; output capacity = level capacity)
    ]
)
connect!(snapshot, battery, grid) # connect the battery to the grid. NB both input and output will be connected

# Optimization
optimize!(snapshot, cost)
result = extract(snapshot)
```

The table of capacities of the optimized system is given below.

```julia
julia> table(result, capacity)
1×3 DataFrame
 Row │ PV       battery  consumption 
     │ Float64  Float64  Float64
─────┼───────────────────────────────
   1 │ 50373.4  5628.94          0.0
```

As we have defined `evalprice=true` at the grid node instantiation, we can calculate the hourly electricity price (€/MWh) as the dual of the "production >= consumption" constraint at each hour. Please note: the dual is not available in problems with integer constraints.

```
julia> p = dualprice(result.nodes["grid"]); # binds a price vector to p

julia> minimum(p)
-0.0

julia> maximum(p)
3516.0807550572163

julia> sum(p)/length(p) # unweighted average
111.78592911234246
```


### Example 2.2: PV and battery storage on two power nodes

In the following example, the system has two power nodes.
  * grid 1: has PV, consumption
  * grid 2: has PV (with different time series of load profile), battery storage

Both power nodes are connected through transmission, that is modeled as unidirectional for the sake of simplicity.

```julia
using Nosy
using HiGHS

s = Sim(Model(HiGHS.Optimizer); mesh=TimeMesh())

elec_carrier = EnergyCarrier("power", s)
co2_carrier = CO2Carrier("co2", s)

# Synthetic data for load
hours = 1:8760
day_angle = 2pi .* ((hours .- 1) .% 24) ./ 24
season_angle = 2pi .* (hours .- 1) ./ 8760
load_profile = 3000 .+ 1500 .* sin.(day_angle .- pi/2) .+ 120 .* sin.(season_angle .- pi/2)

# Synthetic data for PV
cf_pv1 = [x < 1e-6 ? 0.0 : x for x in [max(0, cos((h%24 - 12)/12*pi) * (0.6 + 0.4*sin(2*pi*(h/24)/365))) for h in 1:8760]]
cf_pv2 = circshift(cf_pv1, 1) # similar profile, but shifted by one hour

# Snapshot initialization
snapshot = Snapshot(s)

# Two electricity nodes
grid1 = Node("grid1", elec_carrier, rule=:curtailed, evalprice=true) # we will evaluate the hourly electricity price on this node
grid2 = Node("grid2", elec_carrier, rule=:curtailed)

# Component: Electricity consumption
consumption = Component(
    "consumption",
    Demand(elec_carrier, load_profile),
)
connect!(snapshot, consumption, grid1) # connect the consumption component to the grid 1

# Component: PV on grid 1
pv1 = Component(
    "PV1",
    ProfileSource(elec_carrier, cf_pv1),
    [
        VariableCapacity("output", energy, lb=5000, ub=10000), # Behavior: variable capacity associated with the output of the PV, bounds are 5000 to 10000 MW
        FixedCost(:capex, "output", energy, 50000),
    ]
)
connect!(snapshot, pv1, grid1) # connect the PV 1 to the grid 1

# Component: PV on grid 2
pv2 = Component(
    "PV2",
    ProfileSource(elec_carrier, cf_pv2),
    [
        VariableCapacity("output", energy),
        FixedCost(:capex, "output", energy, 50000),
    ]
)
connect!(snapshot, pv2, grid2) # connect the PV 2 to the grid 2

# Component: battery storage connected on grid 2
battery = Component(
    "battery",
    BasicStorage(elec_carrier, elec_carrier, elec_carrier, energy, eff_i=0.85),
    [
        VariableCapacity("input", energy),
        FixedCost(:capex, "input", energy, 50000),
        Duration(6),
    ]
)
connect!(snapshot, battery, grid2)

# Component transmission (unidirectional) grid 2 to grid 1
transmission = Component(
    "transmission",
    BasicConverter(elec_carrier, elec_carrier), # no losses
    [
        FixedCapacity("input", energy, 8000), # Fixed capacity of 8000 MW
    ]
)
connect!(snapshot, transmission, grid2, "input") # selective connection of the input of the transmission to grid 2
connect!(snapshot, transmission, grid1, "output") # selective connection of the output of the transmission to grid 1

# Optimization
optimize!(snapshot, cost)
result = extract(snapshot)
```

The table of capacities of the optimized system is given below. The PV1 component's capacity is equal to the upper bound.

```julia
julia> table(result, capacity)
1×5 DataFrame
 Row │ PV1      PV2      battery  consumption  transmission 
     │ Float64  Float64  Float64  Float64      Float64
─────┼──────────────────────────────────────────────────────
   1 │ 10000.0  40282.4  5491.59          0.0        8000.0
```


### Example 2.3: PV, battery storage and electrolyzer with power and hydrogen demand

In the following example, we have two demands:
  * power (variable demand in MW)
  * hydrogen (constant demand in tons per hour)

As well as the following components:
  * PV, with variable capacity
  * battery storage, with variable capacity
  * electrolyzer, with variable capacity
  * hydrogen storage, with fixed capacity

In particular, we will pay attention to the relationship between `mass` and `energy` of hydrogen. Some components will interact with its `mass`, other with its `energy`.

```julia
using Nosy
using HiGHS

s = Sim(Model(HiGHS.Optimizer); mesh=TimeMesh())

elec_carrier = EnergyCarrier("power", s)
h2_carrier = MassCarrier("hydrogen", s, energy=33.33) # energy density of H2 is: 33.33 MWh/t [HHV]

# Synthetic data for load
hours = 1:8760
day_angle = 2pi .* ((hours .- 1) .% 24) ./ 24
season_angle = 2pi .* (hours .- 1) ./ 8760
load_profile = 3000 .+ 1500 .* sin.(day_angle .- pi/2) .+ 120 .* sin.(season_angle .- pi/2)

# Synthetic data for H2 demand
h2load = 10. # tons per hour

# Synthetic data for PV
cf_pv = [x < 1e-6 ? 0.0 : x for x in [max(0, cos((h%24 - 12)/12*pi) * (0.6 + 0.4*sin(2*pi*(h/24)/365))) for h in 1:8760]]

# Snapshot initialization
snapshot = Snapshot(s)

# One electricity node and one hydrogen node
grid = Node("grid", elec_carrier, rule=:curtailed, evalprice=true)
h2_node = Node("hydrogen", h2_carrier, rule=:default, evalprice=true) # node is not curtailed: no H2 losses

# Component: Electricity consumption
consumption = Component(
    "consumption",
    Demand(elec_carrier, load_profile),
)
connect!(snapshot, consumption, grid)

# Component: Hydrogen demand
h2_consumption = Component(
    "H2 consumption",
    Demand(h2_carrier, h2load, modifier=mass), # constant demand of 10t/hour of H2
)
connect!(snapshot, h2_consumption, h2_node)

# Component: PV
pv = Component(
    "PV",
    ProfileSource(elec_carrier, cf_pv),
    [
        VariableCapacity("output", energy),
        FixedCost(:capex, "output", energy, 50000),
    ]
)
connect!(snapshot, pv, grid)

# Component: PEM electrolyzer
pem = Component(
    "PEM",
    BasicConverter(elec_carrier, h2_carrier, ratio=0.70, modifier=energy), # convert 70% of the electrical energy into hydrogen energy
    [
        VariableCapacity("input", energy), # capacity as input (electrical) energy capacity (MW)
        FixedCost(:capex, "input", energy, 60000),
    ]    
)
connect!(snapshot, pem, grid)
connect!(snapshot, pem, h2_node)

# Component: battery storage
battery = Component(
    "battery",
    BasicStorage(elec_carrier, elec_carrier, elec_carrier, energy, eff_i=0.85),
    [
        VariableCapacity("input", energy),
        FixedCost(:capex, "input", energy, 50000),
        Duration(6),
    ]
)
connect!(snapshot, battery, grid)

# Component: hydrogen storage (fixed capacity linked to demand, no cost)
h2storage = Component(
    "H2 storage",
    BasicStorage(h2_carrier, h2_carrier, h2_carrier, energy), # no losses
    [
        FixedCapacity("level", energy, h2load * 24 * 3), # assume 3 equivalent days of hydrogen demand as maximum hydrogen storage
    ]
)
connect!(snapshot, h2storage, h2_node)

# Optimization
optimize!(snapshot, cost)
result = extract(snapshot)
```

The capacities of the components in the cost-optimal solution are accessed as before. Please take note: the meaning of the capacity is fully dependent on how they were built. In particular:
  * H2 consumption: t/hour
  * H2 storage: maximum H2 level (tons)
  * PEM: electricity input (MW)
  * PV: electricity output (MW)
  * battery: electricity input (MW)
  * no capacity for the consumption terms

```julia
julia> table(result, capacity)
1×6 DataFrame
 Row │ H2 consumption  H2 storage  PEM      PV       battery  consumption 
     │ Float64         Float64     Float64  Float64  Float64  Float64
─────┼────────────────────────────────────────────────────────────────────
   1 │            0.0       720.0  604.714  58406.1  6631.02          0.0
```

We can check the hydrogen mass generated annually, which is equal to the hourly consumption (10 t) multiplied with the hours per year (8760).

```julia
julia> balance(result, "PEM", :output, mass, collapse=true, aggregate=true) # mass balance, in tons per year
87600.00000000552
```

We can also check this result in terms of energy balance.

```julia
julia> balance(result, "PEM", :output, energy, collapse=true, aggregate=true) # energy balance, in MWh per year
2.919707999999801e6
```

### Example 2.4: Operating reserve (up and down) with a minimum requirement

In this example, a gas plant and a nuclear unit both provide upward and downward reserve. Each direction uses its own reserve name (`"reserve_up_15min"` and `"reserve_down_15min"`), with a 0.25 h delivery duration (15 minutes). A minimum reserve at the node (50 MW in each direction) is enforced by adding a constraint with `reserve(snap, node_name, sense, rname)` and JuMP's `@constraint(model(sim(snapshot)), ...)`.

```julia
using Nosy
using HiGHS
import JuMP: @constraint # do not use `using JuMP`; both JuMP and Nosy export `optimize!`

s = Sim(Model(HiGHS.Optimizer); mesh=TimeMesh())
elec_carrier = EnergyCarrier("power", s)

# Synthetic data for load
hours = 1:8760
day_angle = 2pi .* ((hours .- 1) .% 24) ./ 24
season_angle = 2pi .* (hours .- 1) ./ 8760
load_profile = 3000 .+ 1500 .* sin.(day_angle .- pi/2) .+ 120 .* sin.(season_angle .- pi/2)

# Snapshot initialization
snapshot = Snapshot(s)

# One electricity node
grid = Node("grid", elec_carrier, rule=:curtailed)

# Component: Electricity consumption
consumption = Component("consumption", Demand(elec_carrier, load_profile))
connect!(snapshot, consumption, grid)

# Component: gas plant (dispatchable, ramping, reserve up and down, 15 min duration)
gasplant = Component("gasplant", DispatchableSource(elec_carrier), 
    [
    FixedCapacity("output", energy, 2000.0),
    Ramping("output", :up, 100.0; modifier=energy),
    Ramping("output", :down, 100.0; modifier=energy),
    VariableCost(:fuel, "output", energy, 50.0),
    ReserveUp("reserve_up_15min", "output", :up, 0.25; modifier=energy),
    ReserveDown("reserve_down_15min", "output", :down, 0.25; modifier=energy),
])
connect!(snapshot, gasplant, grid)

# Component: nuclear (dispatchable, ramping, reserve up and down, 15 min duration)
nuclear = Component("nuclear", DispatchableSource(elec_carrier), 
    [
    FixedCapacity("output", energy, 3000.0),
    Ramping("output", :up, 50.0; modifier=energy),
    Ramping("output", :down, 50.0; modifier=energy),
    VariableCost(:dispatch, "output", energy, 10.0),
    ReserveUp("reserve_up_15min", "output", :up, 0.25; modifier=energy),
    ReserveDown("reserve_down_15min", "output", :down, 0.25; modifier=energy),
])
connect!(snapshot, nuclear, grid)

# Minimum reserve at node "grid": total up / total down >= 50 MW (each uses its own reserve name)
@constraint(model(sim(snapshot)), reserve(snapshot, "grid", :up, "reserve_up_15min").data .>= 50.0)
@constraint(model(sim(snapshot)), reserve(snapshot, "grid", :down, "reserve_down_15min").data .>= 50.0)

# Optimization
optimize!(snapshot, cost)
result = extract(snapshot)
```

Reserve can be inspected at three levels (snapshot total, node total, per component). Upward reserve uses `rname` `"reserve_up_15min"` with sense `:up`; downward reserve uses `"reserve_down_15min"` with sense `:down`.

  * `reserve(result, :up, "reserve_up_15min")` / `reserve(result, :down, "reserve_down_15min")` - total over all components
  * `reserve(result, "grid", :up, "reserve_up_15min")` - total upward reserve at node `"grid"` (and similarly with `:down`, `"reserve_down_15min"`)
  * `reserve(result, "gasplant", :up, "reserve_up_15min")` (and similarly for `"nuclear"`) - per component

Upward reserve (example):

```julia
julia> reserve(result, :up, "reserve_up_15min")
8760-element Nosy.Stepwise{Float64}:
 50.0
 50.0
...

julia> reserve(result, "grid", :up, "reserve_up_15min")
8760-element Nosy.Stepwise{Float64}:
 50.0
 50.0
...

julia> reserve(result, "gasplant", :up, "reserve_up_15min")
8760-element Nosy.Stepwise{Float64}:
 0.024
...

julia> reserve(result, "nuclear", :up, "reserve_up_15min")
8760-element Nosy.Stepwise{Float64}:
 49.97
...
```

Downward reserve (same pattern with `:down` and `"reserve_down_15min"`): total and node are 50 MW each step; gas and nuclear split it (often one at 50, the other at 0, depending on the step).

```julia
julia> reserve(result, :down, "reserve_down_15min")
8760-element Nosy.Stepwise{Float64}:
 50.0
 50.0
...

julia> reserve(result, "gasplant", :down, "reserve_down_15min")
8760-element Nosy.Stepwise{Float64}:
 0.0
 50.0
...

julia> reserve(result, "nuclear", :down, "reserve_down_15min")
8760-element Nosy.Stepwise{Float64}:
 50.0
 0.0
...
```

### Example 2.5: PV, battery, and upward reserve

In this example, demand, PV, and a battery are on the same curtailed node. The battery adds two `ReserveUp` behaviors `:up` sense on the output port and `:down` sense on the input port (headroom to cut charging), with reserve names `"reserve_up_discharge_15min"` and `"reserve_up_charge_15min"` and 0.25 h duration. A single `@constraint` forces the sum of `reserve(snapshot, "grid", :up, ...)` for those names to be at least 600MW each timestep

```julia
using Nosy
using HiGHS
import JuMP: @constraint # do not use `using JuMP`; both JuMP and Nosy export `optimize!`

s = Sim(Model(HiGHS.Optimizer); mesh=TimeMesh())
elec_carrier = EnergyCarrier("power", s)

# Synthetic data for load
hours = 1:8760
day_angle = 2pi .* ((hours .- 1) .% 24) ./ 24
season_angle = 2pi .* (hours .- 1) ./ 8760
load_profile = 3000 .+ 1500 .* sin.(day_angle .- pi/2) .+ 120 .* sin.(season_angle .- pi/2)

# Synthetic data for PV
cf_pv = [x < 1e-6 ? 0.0 : x for x in [max(0, cos((h%24 - 12)/12*pi) * (0.6 + 0.4*sin(2*pi*(h/24)/365))) for h in 1:8760]]

# Snapshot initialization
snapshot = Snapshot(s)

# One electricity node
grid = Node("grid", elec_carrier, rule=:curtailed)

# Component: Electricity consumption
consumption = Component("consumption", Demand(elec_carrier, load_profile))
connect!(snapshot, consumption, grid)

# Component: PV
pv = Component(
    "PV",
    ProfileSource(elec_carrier, cf_pv),
    [
        VariableCapacity("output", energy),
        FixedCost(:capex, "output", energy, 50000),
    ],
)
connect!(snapshot, pv, grid)

# Component: battery (fixed capacities, ramping)
# ReserveUp: output with :up (more discharge), input with :down (less charging)
battery = Component(
    "battery",
    BasicStorage(elec_carrier, elec_carrier, elec_carrier, energy, eff_i=0.85),
    [
        FixedCapacity("output", energy, 5000.0),
        FixedCapacity("input", energy, 5000.0),
        FixedCapacity("level", energy, 30000.0),
        Ramping("output", :up, 5000.0; modifier=energy),
        Ramping("output", :down, 5000.0; modifier=energy),
        Ramping("input", :up, 5000.0; modifier=energy),
        Ramping("input", :down, 5000.0; modifier=energy),
        ReserveUp("reserve_up_discharge_15min", "output", :up, 0.25; modifier=energy),
        ReserveUp("reserve_up_charge_15min", "input", :down, 0.25; modifier=energy),
    ],
)
connect!(snapshot, battery, grid)

# Minimum combined upward reserve at node "grid" (600 MW per timestep)
@constraint(
    model(sim(snapshot)),
    reserve(snapshot, "grid", :up, "reserve_up_discharge_15min").data .+
    reserve(snapshot, "grid", :up, "reserve_up_charge_15min").data .>= 600.0,
)

# Optimization
optimize!(snapshot, cost)
result = extract(snapshot)
```

When the level is high, discharge upward reserve often supplies the 6 MW; when it is low, more shifts to the charge upward reserve. Only the battery provides these reserves here, so totals at the grid match the battery.

```julia
julia> balance(result, "battery", :level, energy, collapse=false, aggregate=true)
8760-element Nosy.Hourly{Float64}:
 8942.300011154877
 7536.744365437882
 6030.707710824039
 4330.556648912984
 2355.886348958197
 0.0
 0.0
...

julia> reserve(result, "battery", :up, "reserve_up_discharge_15min")
8760-element Nosy.Stepwise{Float64}:
 600.0
 600.0
 600.0
 600.0
 600.0
 0.0
 0.0
...

julia> reserve(result, "battery", :up, "reserve_up_charge_15min")
8760-element Nosy.Stepwise{Float64}:
 0.0
 0.0
 0.0
 0.0
 0.0
 600.0
 600.0
...
```

### Example 3.1: PV and gas, problem infeasibility and conflicts analysis

In this example, we will analyze the infeasibility of a problem. We assume a PV + gas plant production and a consumption. The capacity of the gas plant is variable but has a higher bound that is too low and makes the problem infeasible.

```julia
using Nosy
using HiGHS

s = Sim(Model(HiGHS.Optimizer); mesh=TimeMesh())
elec_carrier = EnergyCarrier("power", s)

# Synthetic data for load
hours = 1:8760
day_angle = 2pi .* ((hours .- 1) .% 24) ./ 24
season_angle = 2pi .* (hours .- 1) ./ 8760
load_profile = 3000 .+ 1500 .* sin.(day_angle .- pi/2) .+ 120 .* sin.(season_angle .- pi/2)

# Synthetic data for PV
cf_pv = [x < 1e-6 ? 0.0 : x for x in [max(0, cos((h%24 - 12)/12*pi) * (0.6 + 0.4*sin(2*pi*(h/24)/365))) for h in 1:8760]]

# Snapshot initialization
snapshot = Snapshot(s)

# One electricity node
grid = Node("grid", elec_carrier, rule=:curtailed)

# Component: Electricity consumption
consumption = Component(
    "consumption",
    Demand(elec_carrier, load_profile),
)
connect!(snapshot, consumption, grid)

# Component: PV
pv = Component(
    "PV",
    ProfileSource(elec_carrier, cf_pv),
    [
        VariableCapacity("output", energy),
        FixedCost(:capex, "output", energy, 50000),
    ]
)
connect!(snapshot, pv, grid)

# Component: gas turbine with limited capacity
gasplant = Component(
    "gasplant",
    DispatchableSource(elec_carrier),
    [
        VariableCapacity("output", energy, ub=3500), # maximum capacity is 3500 MW (not sufficient) 
        FixedCost(:capex, "output", energy, 60000),
        VariableCost(:fuel, "output", energy, 50.),
    ]
)
connect!(snapshot, gasplant, grid)

# Optimization
optimize!(snapshot, cost)
```

The model warns that the problem was not solved.
```julia
julia> result = extract(snapshot)
┌ Warning: System is not optimized. Termination status: INFEASIBLE. Returning the problem instead of the result.
```

Some solvers allow computing an IIS (irreducible infeasible subsystem) associated with the problem. When available, the IIS can be obtained so as to determine which constraints are conflicting. One very important remark is that the IIS is not unique, there may be multiple IIS associated with one problem, and repairing one IIS does not necessarily make the problem feasible.

```julia
julia> conflicts(result.sim)
2-element Vector{JuMP.ConstraintRef}:
 gasplant_energy_out[4698] >= 3505.1400542149804
 gasplant_energy_out[4698] - gasplant_output_energy_cap <= 0
```

The result is easily interpretable: the gas plant energy output must be allowed to go at least above ~3505 MW, but the capacity is bound at 3500. Mathematically, we can calculate that the actual minimum value for the gas plant capacity is 3508.3 MW:

```julia
julia> maximum([iszero(cf_pv[i]) ?  load_profile[i] : 0. for i in eachindex(load_profile)]) # actual minimum capacity, for the whole year
3508.2277959647663
```

Below is a possible fix for the gas plant component. 

```julia
gasplant = Component(
    "gasplant",
    DispatchableSource(elec_carrier),
    [
        VariableCapacity("output", energy, ub=3509),
        FixedCost(:capex, "output", energy, 60000),
        VariableCost(:fuel, "output", energy, 50.),
    ]
)
```


### Example 3.2: PV and gas, minimization of other objectives

In this (academic) example, we will minimize other metrics than the total system cost. First, let's maximize the capacity of the gas plant while keeping the total system cost below a certain threshold, for instance vicinity of cost-optimality.

First, we start with a "normal" run optimizing the total system cost.

```julia
using Nosy
using HiGHS

s = Sim(Model(HiGHS.Optimizer); mesh=TimeMesh())
elec_carrier = EnergyCarrier("power", s)

# Synthetic data for load
hours = 1:8760
day_angle = 2pi .* ((hours .- 1) .% 24) ./ 24
season_angle = 2pi .* (hours .- 1) ./ 8760
load_profile = 3000 .+ 1500 .* sin.(day_angle .- pi/2) .+ 120 .* sin.(season_angle .- pi/2)

# Synthetic data for PV
cf_pv = [x < 1e-6 ? 0.0 : x for x in [max(0, cos((h%24 - 12)/12*pi) * (0.6 + 0.4*sin(2*pi*(h/24)/365))) for h in 1:8760]]

# Snapshot initialization
snapshot = Snapshot(s)

# One electricity node
grid = Node("grid", elec_carrier, rule=:curtailed)

# Component: Electricity consumption
consumption = Component(
    "consumption",
    Demand(elec_carrier, load_profile),
)
connect!(snapshot, consumption, grid)

# Component: PV
pv = Component(
    "PV",
    ProfileSource(elec_carrier, cf_pv),
    [
        VariableCapacity("output", energy),
        FixedCost(:capex, "output", energy, 50000),
    ]
)
connect!(snapshot, pv, grid)

# Component: gas turbine
gasplant = Component(
    "gasplant",
    DispatchableSource(elec_carrier),
    [
        VariableCapacity("output", energy),
        FixedCost(:capex, "output", energy, 60000),
        VariableCost(:fuel, "output", energy, 50.),
    ]
)
connect!(snapshot, gasplant, grid)

# Optimization
optimize!(snapshot, cost)
result = extract(snapshot)

c0 = cost(result) # minimum system cost
```

The capacity of the cost-optimized solution is the following.

```julia
julia> table(result, capacity)
1×3 DataFrame
 Row │ PV       consumption  gasplant 
     │ Float64  Float64      Float64
─────┼────────────────────────────────
   1 │ 6151.55          0.0   3508.23
```

Now, let's re-generate a problem with the following changes:
  * the capacity of the gas plant must be maximized. We will minimize the metric `snapshot->-capacity(snapshot, "gasplant")` which returns a scalar (opposite of the gas plant capacity).
  * but the system cost must stay below c0 + 1%. We will use a JuMP constraint.


```julia
using Nosy
using HiGHS
import JuMP: @constraint # do not write `using JuMP` as both JuMP and Nosy export `optimize!`

s = Sim(Model(HiGHS.Optimizer); mesh=TimeMesh())
elec_carrier = EnergyCarrier("power", s)

# Synthetic data for load
hours = 1:8760
day_angle = 2pi .* ((hours .- 1) .% 24) ./ 24
season_angle = 2pi .* (hours .- 1) ./ 8760
load_profile = 3000 .+ 1500 .* sin.(day_angle .- pi/2) .+ 120 .* sin.(season_angle .- pi/2)

# Synthetic data for PV
cf_pv = [x < 1e-6 ? 0.0 : x for x in [max(0, cos((h%24 - 12)/12*pi) * (0.6 + 0.4*sin(2*pi*(h/24)/365))) for h in 1:8760]]

# Snapshot initialization
snapshot = Snapshot(s)

# One electricity node
grid = Node("grid", elec_carrier, rule=:curtailed)

# Component: Electricity consumption
consumption = Component(
    "consumption",
    Demand(elec_carrier, load_profile),
)
connect!(snapshot, consumption, grid)

# Component: PV
pv = Component(
    "PV",
    ProfileSource(elec_carrier, cf_pv),
    [
        VariableCapacity("output", energy),
        FixedCost(:capex, "output", energy, 50000),
    ]
)
connect!(snapshot, pv, grid)

# Component: gas turbine
gasplant = Component(
    "gasplant",
    DispatchableSource(elec_carrier),
    [
        VariableCapacity("output", energy),
        FixedCost(:capex, "output", energy, 60000),
        VariableCost(:fuel, "output", energy, 50.),
    ]
)
connect!(snapshot, gasplant, grid)

# Add a constraint on the system cost, directly using JuMP
@constraint(model(s), cost(snapshot) <= c0 * 1.01) # model(s) returns the JuMP Model

# Optimization
optimize!(snapshot, x->-capacity(x, "gasplant"))
result = extract(snapshot)
```

Let's check the cost of the result.

```julia
julia> cost(result) / c0
1.0100000000000011
```

The cost of the newly optimized result is 1% above the cost-optimized solution, which is compatible with the constraint.

Let's also assess the capacities of the new system. As expected, the new gas plant capacity is higher than in the cost-optimal solution.

```julia
julia> table(result, capacity)
1×3 DataFrame
 Row │ PV       consumption  gasplant 
     │ Float64  Float64      Float64
─────┼────────────────────────────────
   1 │ 6151.55          0.0    3733.8
```

The optimization objective passed to `optimize!` is very flexible. Its only constraint is that it must be a function `f(s::Snapshot{T})::Union{<:Number,T}`, in other words it must be a function of the snapshot returning a JuMP expression (or a number, in which case the objective is constant).

### Example 3.3: Single-level vs bilevel capacity expansion & dispatch

In this example, we apply two different optimization strategies to the same snapshot.

#### Part A: Single-level benchmark

This is the single-level version of the same system. The objective is total system cost (all investment + dispatch costs).

```julia
using Nosy
using HiGHS

s = Sim(Model(HiGHS.Optimizer); mesh=TimeMesh())

elec_carrier = EnergyCarrier("power", s)

# Synthetic data for load
hours = 1:8760
day_angle = 2pi .* ((hours .- 1) .% 24) ./ 24
season_angle = 2pi .* (hours .- 1) ./ 8760
load_profile = 3000 .+ 1500 .* sin.(day_angle .- pi/2) .+ 120 .* sin.(season_angle .- pi/2)

# Snapshot initialization
snapshot = Snapshot(s)

# One electricity node
grid = Node("grid", elec_carrier, rule=:curtailed)

# Component: Electricity consumption
consumption = Component(
    "consumption",
    Demand(elec_carrier, load_profile),
)
connect!(snapshot, consumption, grid)

# Component: user-owned dispatchable (variable capacity)
user_dispatchable = Component(
    "user_dispatchable",
    DispatchableSource(elec_carrier),
    [
        VariableCapacity("output", energy),
        FixedCost(:capex, "output", energy, 50000),
        VariableCost(:dispatch, "output", energy, 45.),
    ]
)
connect!(snapshot, user_dispatchable, grid)

# Component: user-owned intermittent source (variable capacity)
cf_c = [x < 1e-6 ? 0.0 : x for x in [max(0, cos((h%24 - 12)/12*pi) * (0.7 + 0.3*sin(2*pi*(h/24)/365))) for h in 1:8760]]
user_intermittent = Component(
    "user_intermittent",
    ProfileSource(elec_carrier, cf_c),
    [
        VariableCapacity("output", energy),
        FixedCost(:capex, "output", energy, 55000),
    ]
)
connect!(snapshot, user_intermittent, grid)

# Component: other-owned dispatchable (fixed capacity)
other_dispatchable = Component(
    "other_dispatchable",
    DispatchableSource(elec_carrier),
    [
        FixedCapacity("output", energy, 3500),
        VariableCost(:dispatch, "output", energy, 25.),
    ]
)
connect!(snapshot, other_dispatchable, grid)

# Single-level optimization
optimize!(snapshot, cost)
result_s = extract(snapshot)
```

#### Part B: Bilevel

Nosy supports bilevel optimization via [BilevelJuMP](https://github.com/joaquimg/BilevelJuMP.jl). In this example, the lower level (system operator) minimizes dispatch costs for all producers. The upper level (owner of the user assets) minimizes its own investment cost plus its own dispatch cost. We use Gurobi as this example is more computationally intensive.

```julia
using Nosy
using Gurobi
using BilevelJuMP: BilevelModel, IndicatorMode

s = Sim(
    BilevelModel(
        Gurobi.Optimizer,
        mode = IndicatorMode(),
    );
    mesh=TimeMesh()
)

elec_carrier = EnergyCarrier("power", s)

# Synthetic data for load
hours = 1:8760
day_angle = 2pi .* ((hours .- 1) .% 24) ./ 24
season_angle = 2pi .* (hours .- 1) ./ 8760
load_profile = 3000 .+ 1500 .* sin.(day_angle .- pi/2) .+ 120 .* sin.(season_angle .- pi/2)

# Snapshot initialization
snapshot = Snapshot(s)

# One electricity node
grid = Node("grid", elec_carrier, rule=:curtailed)

# Component: Electricity consumption
consumption = Component(
    "consumption",
    Demand(elec_carrier, load_profile),
)
connect!(snapshot, consumption, grid)

# Component: user-owned dispatchable (variable capacity)
user_dispatchable = Component(
    "user_dispatchable",
    DispatchableSource(elec_carrier),
    [
        VariableCapacity("output", energy),
        FixedCost(:capex, "output", energy, 50000),
        VariableCost(:dispatch, "output", energy, 45.),
    ]
)
connect!(snapshot, user_dispatchable, grid)

# Component: user-owned intermittent source (variable capacity)
cf_c = [x < 1e-6 ? 0.0 : x for x in [max(0, cos((h%24 - 12)/12*pi) * (0.7 + 0.3*sin(2*pi*(h/24)/365))) for h in 1:8760]]
user_intermittent = Component(
    "user_intermittent",
    ProfileSource(elec_carrier, cf_c),
    [
        VariableCapacity("output", energy),
        FixedCost(:capex, "output", energy, 55000),
    ]
)
connect!(snapshot, user_intermittent, grid)

# Component: other-owned dispatchable (fixed capacity)
other_dispatchable = Component(
    "other_dispatchable",
    DispatchableSource(elec_carrier),
    [
        FixedCapacity("output", energy, 3500),
        VariableCost(:dispatch, "output", energy, 25.),
    ]
)
connect!(snapshot, other_dispatchable, grid)

# Lower-level: minimize operating cost for all (dispatch)
# Upper-level: minimize user investment cost + user dispatch cost
optimize!(snapshot, variablecost, s -> cost(s, "user_dispatchable") + cost(s, "user_intermittent"))
result_b = extract(snapshot)
```

We can compare `result_s` and `result_b` to analyze the impact of bilevel optimization.

```julia
julia> cost(result_s)
6.7586359241188e8

julia> cost(result_s, "user_dispatchable") + cost(result_s, "user_intermittent")
1.5692279376419443e8

julia> cost(result_b)
7.016918356637425e8

julia> cost(result_b, "user_dispatchable") + cost(result_b, "user_intermittent")
1.1410273417100954e8
```

The results above show the following:
  * single-level optimization has a lower total cost
  * bilevel optimization has a higher total cost, however the user-related cost is lower.

## Authors
  * Guillaume KRIVTCHIK, OECD Nuclear Energy Agency (main author)
  * Yuri BAE, Korea Institute of Energy Technology
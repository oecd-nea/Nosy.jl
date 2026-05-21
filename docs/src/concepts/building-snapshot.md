# Building A Snapshot

This page covers the objects used to describe a system before solving: simulations, carriers, nodes, components, archetypes, behaviors, joint flows, snapshots, time, and tags.

## Simulation

[`Sim`](@ref) stores the shared simulation context: the time mesh, JuMP model,
solver options, and variable-name suffix. Most users create one simulation for
one optimisation problem, then build one or more snapshots on top of it.


## Carriers And Modifiers

Carriers describe what flows through the system:

- [`EnergyCarrier`](@ref) for energy-like flows (including electricity when not using AC or DC lines).
- [`PowerCarrier`](@ref) for AC and DC power-flow line models.
- [`MassCarrier`](@ref) for mass-like flows, optionally with energy density.
- [`CO2Carrier`](@ref) for CO2-equivalent accounting.

Modifiers such as [`energy`](@ref), [`mass`](@ref), and [`co2`](@ref) choose the
view used to evaluate a flow. A hydrogen flow, for example, can be read as tons
with `mass` or as MWh with `energy` when the carrier has an energy density.

The `energy` argument gives an energy density in MWh/t. For a
[`MassCarrier`](@ref), the default view remains `mass`, and the energy density
adds an `energy` view. For an [`EnergyCarrier`](@ref), the default view remains
`energy`, and the energy density adds a `mass` view by using its inverse.

Use a scalar when the conversion is constant across the simulation:

```julia
s = Sim(Model(); mesh=TimeMesh(fill(1//1, 3)))

electricity = EnergyCarrier("power", s)
hydrogen = MassCarrier("hydrogen", s; energy=33.33) # MWh/t
heat = EnergyCarrier("heat", s; energy=4.2)         # MWh/t
```

Use a vector when the conversion changes by hour or timestep. The vector must
have one value per hour or one value per model step:

```julia
s = Sim(Model(); mesh=TimeMesh(fill(1//1, 3)))

fuel = MassCarrier("fuel", s; energy=[11.5, 11.7, 11.6])
seasonal_heat = EnergyCarrier("seasonal heat", s; energy=[3.8, 4.0, 4.1])
```

[`CO2Carrier`](@ref) always has a `mass` view. Its `weight` argument gives a
constant CO2-equivalent weight in t CO2eq/t and defines the `co2` view:

```julia
s = Sim(Model(); mesh=TimeMesh(fill(1//1, 3)))

co2_stream = CO2Carrier("co2", s)            # weight defaults to 1.0
methane = CO2Carrier("methane", s; weight=28.0)
```


## Ports

Carriers flow through ports. Each input or output port has a carrier, which
defines the physical quantity being exchanged, and modifiers define the views in
which that quantity can be measured. A port may also represent a level, such as
the stored energy or mass in a storage component.

Model archetypes own the core ports of a component. A source archetype, for
example, owns an output port; a sink owns an input port; a storage archetype
usually owns input, output, and level ports. Behaviors modify how existing
ports behave by adding capacities, costs, ramping limits, reserves, unit
commitment, or other constraints. Joint flows add new named input or output
ports when a component needs additional flows that are not part of its
archetype.

The ports of components are connected to nodes with [`connect!`](@ref). A node
then collects compatible component ports and applies the local balance rule.

All ports do not must be connected. In particular, `level`s and ports created
by joint flows with the option `mustconnect=false` will not be connected.


## Nodes

[`Node`](@ref)s are accounting junctions. Components connect to nodes, and node
constraints enforce the local flow rule. A default node balances input and
output. A curtailed node allows production to exceed consumption, which is often
useful for electricity systems with renewable curtailment.

Examples of nodes:
  * an electricity bidding zone
  * a country
  * a hydrogen pipeline
  * atmospheric CO2


## Components

[`Component`](@ref)s are active system elements. A component is built from one
model archetype and any number of behaviors and joint flows.


## Model Archetype

Model archetypes define the core port structure and physical role of a
component before behaviors are added.

### [`DispatchableSource`](@ref)

Exposes one output port named `output` and creates one output flow variable per
timestep:

```math
g_t \in [0, +\infty[, \quad t=1,\ldots,N.
```

No archetype-specific constraints are added. Capacity, ramping, cost, reserve,
or unit-commitment behaviors can then restrict or price this output.

### [`ProfileSource`](@ref)

Exposes one output port named `output`. It creates no optimisation variable for
the output flow by itself. A capacity behavior on `output` is mandatory; once
it is added, the output is the capacity times the exogenous profile ``a_t``:

```math
g_t = a_t K.
```

This is the usual archetype for PV, wind, run-of-river hydro, or any source
whose dispatch shape is externally prescribed.

### [`Demand`](@ref)

Exposes one input port named `input`. It creates no variables and no
constraints. The input port is fixed to the provided demand series ``d_t``:

```math
x_t = d_t.
```

### [`BasicSink`](@ref)

Exposes one input port named `input` and creates one flexible input flow
variable per timestep:

```math
x_t \in [0, +\infty[, \quad t=1,\ldots,N.
```

No archetype-specific constraints are added.

### [`BasicConverter`](@ref)

Exposes an input port named `input` and an output port named `output`. It
creates ``N`` input variables and represents the output as an affine expression
of the input. With conversion ratio ``\rho_t``:

```math
x_t \in [0, +\infty[, \qquad y_t = \rho_t x_t.
```

Modifier conversions between carriers are included in the expression. No extra
constraint is needed because the output port directly stores the affine
relation.

### [`BasicStorage`](@ref)

Exposes an input port named `input`, an output port named `output`, and a level
port named `level`. It creates three non-negative variables per timestep: input
``x_t``, output ``y_t``, and level ``\ell_t``. It adds ``N`` periodic
storage-balance constraints. In the default linear-in-time formulation:

```math
\ell_{t+1} - s_t \ell_t =
\frac{\Delta_t}{2}\left(\eta_i(x_{t+1}+x_t) -
\frac{y_{t+1}+y_t}{\eta_o}\right),
```

where ``s_t`` is the self-discharge multiplier, ``\eta_i`` is input
efficiency, and ``\eta_o`` is output efficiency. With `simplified=true`, the
right-hand side uses only the current-step flows:

```math
\ell_{t+1} - s_t \ell_t =
\Delta_t\left(\eta_i x_t - \frac{y_t}{\eta_o}\right).
```

The timestep after ``N`` wraps to timestep ``1``.

### [`LazyStorage`](@ref)

Exposes one level port named `level`. It creates ``N`` non-negative level
variables. Input and output flows are supplied by joint flows rather than by
the archetype itself. It adds ``N`` periodic storage-balance constraints using
the sum of connected input and output joint flows:

```math
\ell_{t+1} - s_t \ell_t =
\Delta_t\left(\sum_i \eta_i x_{i,t} - \sum_j \eta_j y_{j,t}\right)
```

in simplified mode, with a trapezoidal variant otherwise. This is useful when a
storage component needs several named charging or discharging ports.

### [`ACLine`](@ref) And [`DCLine`](@ref)

Both line archetypes expose four ports: output ports `from_out` and `to_out`,
and input ports `from_in` and `to_in`. They create two non-negative
directional flow variables per timestep, one for each direction:

```math
f^{from\to to}_t \in [0,+\infty[, \qquad
f^{to\to from}_t \in [0,+\infty[.
```

The same directional variable appears as an output at one end and an input at
the other. The line archetypes add no local capacity constraints by themselves;
use capacity behaviors to bound the flows. `ACLine` carries admittance data
for power-flow formulations, while `DCLine` is a transport line without
Kirchhoff-voltage-law data.

Model archetype ports are summarized below:

| Model archetype | Input ports | Output ports | Level ports |
| --- | --- | --- | --- |
| [`DispatchableSource`](@ref) | - | `output` | - |
| [`ProfileSource`](@ref) | - | `output` | - |
| [`Demand`](@ref) | `input` | - | - |
| [`BasicSink`](@ref) | `input` | - | - |
| [`BasicConverter`](@ref) | `input` | `output` | - |
| [`BasicStorage`](@ref) | `input` | `output` | `level` |
| [`LazyStorage`](@ref) | - | - | `level` |
| [`ACLine`](@ref) | `from_in`, `to_in` | `from_out`, `to_out` | - |
| [`DCLine`](@ref) | `from_in`, `to_in` | `from_out`, `to_out` | - |


## Behaviors

Behaviors refine a component after the archetype defines its basic ports. They
cover capacity constraints, investment and operating costs, ramping, unit
commitment, reserve provision, and yearly flow limits.

The same archetype can therefore represent several technologies. A dispatchable
source with a fixed capacity and low variable cost can be a nuclear unit; the
same archetype with variable capacity and fuel cost can be a gas turbine.

Public behaviors are grouped into families.

### Capacity

- [`FixedCapacity`](@ref): creates no variable. It fixes one port capacity to a
  numeric value, for example a 1000 MW plant or an 8000 MW interconnector, and
  usually adds ``N`` upper-bound constraints:

  ```math
  f_t \le K.
  ```

  If the targeted flow is a plain variable, Nosy may use variable bounds
  instead of explicit constraints. On [`ProfileSource`](@ref), the capacity is
  folded into ``g_t = a_t K`` instead of adding per-step constraints.

- [`VariableCapacity`](@ref): creates one capacity variable
  ``K \in [K^{min}, K^{max}]``. If `unitsize=U` is provided, the variable is a
  number of units ``q`` and ``K = Uq``; `integer=true` makes ``q`` integer. It
  adds ``N`` constraints:

  ```math
  f_t \le K.
  ```

  When an existing JuMP variable or affine expression is passed through
  `expression`, no new capacity variable is created. Bounds are then enforced
  as one or two constraints on that expression.

- [`FixedComposedCapacity`](@ref): creates no variable and adds ``N``
  constraints on the sum of several port flows:

  ```math
  \sum_{p \in P} f_{p,t} \le K.
  ```

- [`VariableComposedCapacity`](@ref): creates one capacity variable, or one
  unit-count variable when `unitsize` is provided. It requires `weights` in the
  same order as the target ports and adds ``N`` constraints:

  ```math
  \sum_{p \in P} w_p f_{p,t} \le K.
  ```

- [`CapacityMultiplier`](@ref): creates no variable and has no standalone
  constraint. It modifies the matching capacity constraint with a non-negative
  multiplier ``a_t``:

  ```math
  f_t \le a_t K.
  ```

- [`Duration`](@ref): creates no variable. It links storage flow capacity and
  level capacity by adding ``2N`` constraints. If the input or output capacity
  is ``K`` and duration is ``h``:

  ```math
  x_t \le K, \qquad y_t \le K, \qquad \ell_t \le hK.
  ```

  If the level capacity is the one explicitly provided, Nosy instead constrains
  input and output flows by ``K/h``.

### Costs

- [`FixedCost`](@ref): creates no variables and no constraints. It adds a term
  proportional to a matching capacity:

  ```math
  C^{fixed} = cK.
  ```

Please note: in general, a `Snapshot` represents a year. In that case, the fixed
cost is an annualized cost, and is expressed in currency / year.

- [`VariableCost`](@ref): creates no variables and no constraints. It adds an
  operating-cost expression from the targeted flow. For a scalar cost ``c``:

  ```math
  C^{var} = c \sum_t \Delta_t f_t.
  ```

  With a time series cost, Nosy integrates the product of cost and flow using
  either stepwise or linear interpolation (see [`VariableCost`](@ref) constructor)

- [`NoLoadCost`](@ref): creates no variables and no constraints. With unit
  commitment, it adds an online cost based on the number of units that are up:

  ```math
  C^{nl} = c \sum_t \Delta_t u_t.
  ```

- [`StartupCost`](@ref): creates no variables and no constraints. With unit
  commitment, it adds a per-start cost:

  ```math
  C^{su} = c \sum_t su_t.
  ```

### Technological Constraints

- [`Duration`](@ref): see the capacity family above. It is listed here too
  because it represents the technical relation between storage power capacity
  and energy capacity.

- [`Ramping`](@ref): creates no variables and adds ``N`` constraints. For
  upward ramping:

  ```math
  f_{t+1} - f_t \le \Delta_t R.
  ```

  Downward ramping uses ``f_{t+1} - f_t \ge -\Delta_t R``. If the component has
  unit commitment, the limit is applied to the variable committed flow and
  scaled by the committed state. If the component has a unit size but no unit
  commitment, the limit is scaled by the number of units.

- [`UnitCommitment`](@ref): requires a single-port capacity with `unitsize`.
  Without masks, it creates ``N`` startup variables, ``N`` state variables,
  ``D \times N`` shutdown-selector variables for ``D`` downtime alternatives,
  and up to ``N`` variable-output variables when `minratio < 1`. These variables
  are continuous by default and become integer when `integer=true`. Startup and
  shutdown masks can reduce the number of startup, shutdown, and state
  variables.

  The main constraints include the state transition:

  ```math
  u_t = u_{t-1} + su_t - sd_{t-1},
  ```

  the variable-output bound:

  ```math
  v_t \le u_t U(1-r^{min}),
  ```

  the flow identity:

  ```math
  f_t = r^{min} U u_t + v_t + f^{startup}_t + f^{shutdown}_t,
  ```

  plus minimum-up, minimum-down, shutdown-selection, and
  shutdown-not-above-state constraints. Integer unit commitment generally has a
  large impact on optimisation time because it turns the commitment decisions
  into integer variables.

- [`ReserveUp`](@ref) and [`ReserveDown`](@ref): without unit commitment, each
  reserve behavior creates ``N`` reserve variables ``r_t \ge 0``. Upward
  reserve is bounded by headroom and downward reserve by current flow:

  ```math
  r_t \le K_t - f_t \quad \text{(up)}, \qquad
  r_t \le f_t \quad \text{(down)}.
  ```

  If a matching ramping behavior exists, another ``N`` constraints are added;
  for upward reserve:

  ```math
  f_{t+1} - f_t + r_t \le \Delta_t R.
  ```

  On storage models, upward reserve also adds ``N`` energy-limit constraints,
  for example ``r_t \le \eta \ell_t / h`` on an output port.

  With fleet unit commitment, Nosy creates three reserve series: total reserve
  ``r_t``, online reserve ``r^{online}_t``, and fast reserve ``r^{fast}_t``.
  Capacity constraints bound online reserve by committed headroom and fast
  reserve by units that can start up or shut down within the reserve duration,
  then enforce:

  ```math
  r_t = r^{online}_t + r^{fast}_t.
  ```

### Flows

- [`YearlySum`](@ref): creates no variables and adds one constraint on the
  annual sum of a port flow, calculated as trapezoidal integral assuming 
  [linear trends between instants](#time).

  ```math
  \sum_t \frac{\Delta_{t-1} + \Delta_t}{2} f_t \le B, \qquad
  \sum_t \frac{\Delta_{t-1} + \Delta_t}{2} f_t = B, \quad \text{or} \quad
  \sum_t \frac{\Delta_{t-1} + \Delta_t}{2} f_t \ge B.
  ```


## Joint Flows

Joint flows create a new input or output port on a component in addition to the
ports created by the model archetype. The new port is named by the joint flow's
`name` argument and its side is set by `sense`, which must be `:input` or
`:output`. By default, `mustconnect=true`, so the port must be connected before
the snapshot is optimized. With `mustconnect=false`, the port may remain
unconnected. Joint flows are useful when a technology has secondary flows that
are not part of its basic archetype: emissions, fuel consumption, by-products,
co-products, auxiliary consumption, or an extra commodity linked to the main
operation.

Joint-flow types are:

- [`FixedJointFlow`](@ref): creates a new port with the requested name and
  sense, but creates no variables and no constraints. It adds an exogenous input
  or output profile to a component. Use it for fixed auxiliary consumption,
  fixed emissions, or any additional flow known before optimisation.
- [`FreeJointFlow`](@ref): creates a new port with the requested name and sense,
  backed by ``N`` non-negative variables as an extra component flow. Use it when
  the additional flow is a decision variable but is not already represented by
  the archetype.
- [`LinkedJointFlow`](@ref): creates a new port with the requested name and
  sense, but creates no variables and no constraints. It adds a flow computed
  from other component flows. For example:

  ```math
  e_t = K - 2 * \alpha g_t.
  ```

Use joint flow for proportional fuel use, CO2 emissions linked to output, 
conversion losses, CHP, or other derived flows.

Joint flows behave like regular component ports once created: they can be
connected to nodes, used in balances, assigned costs, included in storage
balances, and queried afterward.


## Snapshots

[`Snapshot`](@ref)s are the model instances built inside a simulation. After
defining nodes and components, you must attach them to a snapshot with
[`connect!`](@ref). Connection adds the component and node to the snapshot if
needed, links compatible ports, and gives the snapshot enough information to
apply node balances.

The snapshot is then the object passed to [`optimize!`](@ref) and
[`extract`](@ref). Several snapshots can share the same [`Sim`](@ref), which is
useful when multiple system states or scenarios must live in one JuMP model.
Balances and metrics such as [`cost`](@ref), [`capacity`](@ref), and
[`reserve`](@ref) can be queried on a snapshot before optimisation, where they
return JuMP expressions, or on the extracted result, where they return numeric
values.

The details below use ``N`` for the number of model timesteps and
``\Delta_t`` for the duration of timestep ``t`` in hours. Unless stated
otherwise, variables are continuous and non-negative.


## Time

Nosy uses the following time conventions:

  * Internally, Nosy works with irregular time meshes through the custom
    `Stepwise` wrapper. `Stepwise` series are cyclic: the index after the final
    index wraps to the first one.
  * User-facing time-series wrappers are `Hourly` series. They represent regular
    hourly meshes interpolated from `Stepwise` data, and are cyclic too.
  * `Stepwise` and `Hourly` behave like circular vectors, modulo the number of
    steps or hours respectively. In particular, for both wrappers, `v[0] ==
    v[end]`, `v[-1] == v[end-1]`, and so on.
  * Quantities are interpreted as values at an instant, not over a time
    interval. In that sense, Nosy uses a "power" formalism rather than an
    "energy" formalism. The power formalism creates more nonzeros in the
    optimization matrix, so affected models, such as storage, offer a `simplified`
    keyword argument to fall back to the energy formalism locally. This is
    generally a good approximation when the component is not central to the
    study, such as a plant in a background node.
  * Quantities are assumed to vary linearly between instants whenever possible.
    This applies to all flows, is an approximation for levels because quadratic
    components are not modeled, and does not hold for unit-commitment state and
    switch variables.

[`TimeMesh`](@ref) maps a full year of hours onto model timesteps. The default
mesh represents 8760 hourly steps. Custom meshes allow sub-hourly and irregular
timesteps, but each timestep weight must be no longer than one hour.


## Tags

Components and nodes can be tagged with [`tag!`](@ref), queried with
[`hastag`](@ref), and filtered with [`getcomponents`](@ref) or
[`getnodes`](@ref). Tags are useful for scenario dashboards, grouping
technologies, and applying reports to selected subsets of a snapshot.

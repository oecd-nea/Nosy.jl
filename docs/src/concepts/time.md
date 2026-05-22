# Time

## Time conventions

Quantities are interpreted as values at an instant, not over a time
interval. In that sense, Nosy uses a "power" formalism rather than an
"energy" formalism. The power formalism creates more nonzeros in the
optimization matrix, so affected models, such as storage, offer a `simplified`
keyword argument to fall back to the energy formalism locally. This is
generally a good approximation when the component is not central to the
study, such as a plant in a background node.

Quantities are assumed to vary linearly between instants whenever possible.
This applies to all flows, and is an approximation for levels because quadratic
components are not modeled. However, this formalism does not apply to all non-flow
vectors. In particular, the exceptions are:
  * [`UnitCommitment`](@ref) state and switch variables: they are to be considered as instantaneous, Dirac-like.
  * [`VariableCost`](@ref) time-dependent cost, that can be either linear or a step function.

## TimeMesh

[`TimeMesh`](@ref Nosy.TimeMesh) controls the temporal resolution of the model.
The default `TimeMesh` is full year with 8760 hourly timesteps:

```julia
s = Sim(HiGHS.Optimizer; mesh=TimeMesh())
```

The default `TimeMesh` is circular: time is modeled as a 


For quick prototypes, one can use a shorter horizon, such as one 30-day month.
This is only a development convenience for checking model structure, costs,
connections, and reporting code; it is not an approximation of the full yearly
scenario:

```julia
# A 30-day prototype horizon with hourly timesteps.
mesh = TimeMesh(fill(1, 24 * 30))
s = Sim(HiGHS.Optimizer; mesh=mesh)
```

Irregular meshes are useful when some hours need more detail than others. The
current `TimeMesh` API accepts timestep weights smaller than zero. 

Timesteps longer than one hour can be useful to reduce the numerical complexity
of the optimization. 

```julia
# One day with two-hours time steps between 0 and 4h, and one-hour timesteps
# for the rest of the day
night = fill(2, 2)
day = fill(1, 20)
mesh = TimeMesh(vcat(night, day))
```

Timesteps shorter than one hour can help describe sub-hourly phenomena, but add 
numerical complexity to the simulation. Use `Rational` number for sub-hourly
timesteps. 

```julia
# One day: hourly night steps, finer morning and evening ramps.
night = fill(1, 8)
morning_ramp = fill(1//2, 8)
day = fill(1, 8)
evening_ramp = fill(1//2, 8)

mesh = TimeMesh(vcat(night, morning_ramp, day, evening_ramp))
```

Custom meshes with timesteps above one hourshould be used with care. 
Nosy constraints are applied on the
mesh you provide, so changing temporal resolution is a modelling approximation:
it can speed up the solve, but it can also hide quick events relative to 
ramps, startup, scarcity periods etc. It is advised to validate custom `TimeMesh` 
before production use.

## Time series

Internally, Nosy works with irregular time meshes through the custom
`Stepwise` wrapper. Each `Stepwise` index is a step in the `TimeMesh`.

User-facing time-series wrappers are `Hourly` series. They represent regular
hourly meshes interpolated from `Stepwise` data, using the step durations
from the `TimeMesh`.

If the `TimeMesh` is circular, then `Stepwise` and `Hourly` behave like 
circular vectors, modulo the number of steps or hours respectively. 
In particular, for both wrappers, `v[0] == v[end]`, `v[-1] == v[end-1]`, 
and so on.
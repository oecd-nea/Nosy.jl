# Performance

In most Nosy studies, computation time is dominated by optimisation in the
solver, not by Nosy's model generation. If model generation itself becomes
noticeable, the usual Julia advice applies: keep code type-stable, avoid
unnecessary allocations, and work with functions. See Julia's
[Performance Tips](https://docs.julialang.org/en/v1/manual/performance-tips/)
for the general toolbox.

In problems with a very large number of variables, the creation of variable names
may take a non-negligible time. If you do not need the variable names, you
can use the function `set_string_names_on_creation` from the package JuMP.

```julia
JuMP.set_string_names_on_creation(model(sim(snapshot)), false) 
```

The levers below mostly target solver time by reducing model size, dropping
irrelevant tiny coefficients, or improving numerical conditioning.

## Objective Cleanup

[`optimize!`](@ref) filters small objective coefficients before sending the
objective to JuMP. The threshold is read from the simulation option
`objthreshold`, whose default value is `1e-9`.

```julia
using Nosy
using HiGHS

s = Sim(HiGHS.Optimizer; objthreshold=1e-8)
```

The threshold is relative to the largest absolute objective coefficient. Terms
below the threshold are removed, and Nosy emits a warning if any terms are
dropped. This is useful when tiny numerical terms accumulate in a large
objective and add noise without changing the economics of the problem.

Use this carefully: if a coefficient is small because the unit scale is small
but the term is still meaningful, increasing `objthreshold` may change the
model.

## Constraint Cleanup And Scaling

By default, [`Sim`](@ref) wraps optimiser constructors in Nosy's constraint
scaling bridge:

```julia
s = Sim(HiGHS.Optimizer; constraint_scaling=true)
```

The bridge rewrites scalar affine constraints before they reach the solver. For
each constraint row, it:

- removes coefficients, left-hand-side constants, and right-hand-side bounds
  below `expthreshold * maxabs`, where `maxabs` is the largest finite
  coefficient in that row;
- scales the row so that the geometric mean of the smallest and largest finite
  nonzero absolute values is equal to `scalingtarget`.

The defaults are:

```julia
s = Sim(
    HiGHS.Optimizer;
    constraint_scaling=true,
    expthreshold=1e-9,
    scalingtarget=1.0,
)
```

This is an MOI bridge, so it changes the representation of scalar affine
constraints passed to the optimiser. It does not rewrite variable bounds,
integrality constraints, vector constraints, quadratic constraints, or
nonlinear constraints.

To disable this bridge:

```julia
s = Sim(HiGHS.Optimizer; constraint_scaling=false)
```

## Small Bound Cleanup

Nosy can also fix nonnegative variables to zero when their upper bound is below
`boundthreshold`. The default value is `1e-3`.

```julia
s = Sim(HiGHS.Optimizer; boundthreshold=1e-4)
```

This can reduce model size when preprocessing has created tiny-capacity
variables. As with objective cleanup, the threshold should be consistent with
the units of the model.

## Unit Commitment Masks

[`UnitCommitment`](@ref) can create many variables and constraints, especially
on long meshes. Setting `integer=true` does not by itself create more
constraints, but it turns the commitment decisions into integer variables and
can make the optimisation problem much harder for the solver. When starts or
shutdowns only need to be considered at selected timesteps, use `startupmask`
and `shutdownmask` to avoid creating unnecessary event variables.

```julia
# Only allow starts every four hours.
startupmask = falses(8760)
startupmask[1:4:end] .= true

# Only allow shutdowns every four hours for the single downtime type.
shutdownmask = [copy(startupmask)]

uc = UnitCommitment(
    "output",
    0.4;
    startup=2,
    shutdown=1,
    uptime=6,
    downtime=4,
    integer=true,
    startupmask=startupmask,
    shutdownmask=shutdownmask,
)
```

The masks should have one Boolean value per timestep in the simulation mesh.
`startupmask=false` disallows startups at that timestep. Each vector in
`shutdownmask` applies to one shutdown type; its length must match the number
of downtime alternatives.

## Time

[`TimeMesh`](@ref) controls the temporal resolution of the model. A full hourly
year creates 8760 timesteps:

```julia
s = Sim(HiGHS.Optimizer; mesh=TimeMesh())
```

For quick prototypes, you can use a shorter horizon, such as one 30-day month.
This is only a development convenience for checking model structure, costs,
connections, and reporting code; it is not an approximation of the full yearly
scenario:

```julia
# A 30-day prototype horizon with hourly timesteps.
mesh = TimeMesh(fill(1//1, 24 * 30))
s = Sim(HiGHS.Optimizer; mesh=mesh)
```

Irregular meshes are useful when some hours need more detail than others. The
current `TimeMesh` API accepts timestep weights in `(0, 1]`: it can split
eventful hours into sub-hourly steps, but it does not support timesteps longer
than one hour.

```julia
# One day: hourly night steps, finer morning and evening ramps.
night = fill(1//1, 8)
morning_ramp = repeat([1//4, 3//4], 4)
day = fill(1//1, 8)
evening_ramp = repeat([1//4, 3//4], 4)

mesh = TimeMesh(vcat(night, morning_ramp, day, evening_ramp))
s = Sim(HiGHS.Optimizer; mesh=mesh)
```

Custom meshes should be used with care. Nosy constraints are applied on the
mesh you provide, so changing temporal resolution is a modelling approximation:
it can speed up the solve, but it can also hide short events, ramps, scarcity
periods, storage cycling, and unit-commitment transitions.

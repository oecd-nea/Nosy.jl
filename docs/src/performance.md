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

## Model archetype simplifications

Some models offer a simplified version of the equations, which can help reduce
the computational burden of the optimization. In particular, the
[`BasicStorage`](@ref) and [`LazyStorage`](@ref) constructors have the
`simplified` keyword argument, which slightly changes the expression of the
level as a function of the flows by using the simpler "energy" formalism
instead of the "power" formalism.

Please validate before using the `simplified=true` argument in production.

## Time mesh

The number of optimization variables is generally linear with the number of timesteps.
Depending on the model's goal, there can be two types of time-related simplifications:
  * reducing the duration of the `TimeMesh`: you can define a smaller temporal horizon, e.g. sub-annual duration.
  * using a coarser `TimeMesh`, with all or some of the night steps lasting more than one hour.

The [Time](concepts/time.md) section of the documentation provides more detail on how to use a custom [`TimeMesh`](@ref).

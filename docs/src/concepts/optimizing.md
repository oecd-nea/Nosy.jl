# Optimization

## Optimizing a snapshot

Nosy always minimizes objectives. To maximize an expression, minimize its
negative instead.

The objective passed to [`optimize!`](@ref) can be any scalar affine expression:
the usual objective is the total cost of a snapshot, but metrics and arithmetic
can be combined freely.

Examples:

```julia
optimize!(snapshot, cost(snapshot))
optimize!(snapshot, cost(snapshot, :fuel) + cost(snapshot, :startup))
optimize!(snapshot, -capacity(snapshot, "gasplant"))
```

Because optimization is always minimization, minimizing 
`-capacity(snapshot, "gasplant")` maximizes that capacity.

## Optimizing multiple snapshots

[`optimize!`](@ref) can also optimize a vector of snapshots that share the same
simulation. This is useful for more advanced calculations, such as stochastic
programming or optimized pathways.

Example:

```julia
optimize!([snapshot1, snapshot2], cost(snapshot1) + 2 * cost(snapshot2))
```

## Infeasible problems

Some problem are not feasible, generally due to conflicting constraints. In that case, you 
can identify the conflicting constraints using the [`conflicts`](@ref) function. Nosy generates
variables with explicit names to facilitate debug. Please note: the IIS of an infeasible problem
is not necessarily unique, and this step can be iterative.


## Extract results

After optimizing a snapshot, the usual workflow is to [`extract`](@ref) the results, meaning 
generating a snapshot populated with the values of the optimal solution. The generated
result is a replica of the problem snapshot, but with values instead of variables and 
expressions.

```julia
optimize!(snapshot, cost(snapshot))
result = extract(snapshot)
```

## Exporting a problem to file 

Before running the optimizer, [`optimize!`](@ref) calls [`finalize!`](@ref) if
the snapshot has not already been finalized. Finalization adds the node
constraints, checks connections, and cleans up the problem, including variable
bounds. If you want to export the finalized optimization problem before solving
it, set the objective and call [`finalize!`](@ref) explicitly before writing the 
JuMP model:

```julia
finalize!(snapshot)
JuMP.set_objective(model(sim(snapshot)), JuMP.MIN_SENSE, cost(snapshot))
JuMP.write_to_file(model(sim(snapshot)), "example.mps")
```

If your problem is already optimized, there is no need to `finalize!` the 
snapshot, you can call `JuMP.write_to_file` directly.
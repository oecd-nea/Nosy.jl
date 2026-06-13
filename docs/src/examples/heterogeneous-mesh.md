# PV, Storage, And Consumption With Heterogeneous Time Meshes

This example compares the same PV, storage, and flat-consumption system with
three simulation time meshes:

- a normal hourly mesh;
- a coarse 2-hour mesh everywhere;
- a heterogeneous mesh with 1-hour day steps and 2-hour night steps.

The point is to show where a coarse mesh can be useful, but also how it can be
misleading.

The normal hourly time mesh is used as a reference.
A 2-hour mesh everywhere smooths the daylight operation and can change
storage sizing. The heterogeneous mesh keeps hourly resolution during daylight
and only coarsens the night, when there is no PV and the system is only working
on storage.

We define a function that generates and solves a capacity expansion and dispatch
problem, while taking the time mesh as argument. Then, we compare the results
associated with the three meshes.

```jldoctest pv_storage_consumption_mesh; output = false
using Nosy
using DataFrames
using HiGHS
import JuMP: set_silent

normal_mesh = TimeMesh(fill(1//1, 8760))
coarse_mesh = TimeMesh(fill(2//1, 4380))
heterogeneous_day = vcat(fill(2//1, 2), fill(1//1, 18), [2//1])
heterogeneous_mesh = TimeMesh(repeat(heterogeneous_day, 365))

function solve_pv_storage_consumption_case(mesh)
    s = Sim(Model(HiGHS.Optimizer); mesh=mesh)
    set_silent(model(s))

    power = EnergyCarrier("power", s)
    snapshot = Snapshot(s)
    grid = Node("grid", power, rule=:curtailed)

    consumption = Component("consumption", Demand(power, 0.42))
    connect!(snapshot, consumption, grid)

    pv_day = [
        0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
        0.05, 0.20, 0.45, 0.70, 0.90, 1.00,
        0.95, 0.80, 0.55, 0.30, 0.10, 0.0,
        0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
    ]
    pv_profile = repeat(pv_day, 365)

    pv = Component(
        "PV",
        ProfileSource(power, pv_profile),
        [
            VariableCapacity("output", energy),
            FixedCost(:capex, "output", energy, 1.0),
        ],
    )
    connect!(snapshot, pv, grid)

    storage = Component(
        "storage",
        BasicStorage(power, power, power, energy; eff_i=0.92),
        [
            VariableCapacity("input", energy),
            FixedCost(:capex, "input", energy, 0.20),
            Duration(4),
        ],
    )
    connect!(snapshot, storage, grid)

    optimize!(snapshot, cost(snapshot))
    variables = Nosy.nvariables(sim(snapshot))
    constraints = Nosy.nconstraints(sim(snapshot))
    result = extract(snapshot)

    return (;
        result,
        variables,
        constraints,
        objective=cost(result),
        pv=capacity(result, "PV"),
        storage=capacity(result, "storage"),
    )
end

normal = solve_pv_storage_consumption_case(normal_mesh);
coarse = solve_pv_storage_consumption_case(coarse_mesh);
heterogeneous = solve_pv_storage_consumption_case(heterogeneous_mesh);
nothing

# output

```

Expected results:

```jldoctest pv_storage_consumption_mesh
julia> DataFrame(
           mesh=["hourly", "2-hour", "heterogeneous"],
           pv_capacity=[normal.pv, coarse.pv, heterogeneous.pv],
           storage_capacity=[normal.storage, coarse.storage, heterogeneous.storage],
           cost=[normal.objective, coarse.objective, heterogeneous.objective],
           variables=[normal.variables, coarse.variables, heterogeneous.variables],
       )
3×5 DataFrame
 Row │ mesh           pv_capacity  storage_capacity  cost     variables
     │ String         Float64      Float64           Float64  Int64
─────┼──────────────────────────────────────────────────────────────────
   1 │ hourly             1.76842           1.50426  2.06927      26282
   2 │ 2-hour             1.7697            1.40364  2.05042      13142
   3 │ heterogeneous      1.76842           1.50426  2.06927      22997
```

The 2-hour mesh is smaller, but it is not automatically a free win: here it
also changes the storage expansion and the objective value. The heterogeneous
mesh is more deliberate. It simplifies the problem by removing night-time steps
where hourly PV detail is irrelevant, while preserving the same capacity
expansion and cost as the hourly reference.

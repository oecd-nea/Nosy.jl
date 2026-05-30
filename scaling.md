# Nosy Scaling Findings

This note summarizes the scaling experiments run against the SC_KOREA
snapshot benchmark. The performance metric was the sum of `JuMP.solve_time`
over four LP cases:

- `makesnapshot_historical()`
- `makesnapshot_2038()`
- `makesnapshot_2050()`
- `makesnapshot_2050(reserves=true)`

Benchmarks were run by building snapshots with `optimize=false` and
`integer=false`, then calling `Nosy.optimize!(snap, Nosy.cost(snap))` and
recording `JuMP.solve_time(snap.sim.model)`. Solver output was disabled.

## Complexity Scatterplot

![Solve time vs subjective experiment complexity](scaling_experiment_scatter.svg)

The plotted data are stored in `scaling_experiment_scatter.csv`. Only completed
four-case experiments are included. Complexity is a subjective 0-6 score: 0
means no Nosy scaling, while 6 means the most invasive/model-touching
experiment.

The earlier "No Nosy scaling, gated run" value of 177.91 seconds was removed
after a recheck because it was not reproducible. The verified no-scaling recheck
was 304.47 seconds total: historical 7.74, 2038 52.67, 2050 63.88, and 2050
reserves 180.18.

## Reference Results

| Configuration | historical | 2038 | 2050 | 2050 reserves | Total |
| --- | ---: | ---: | ---: | ---: | ---: |
| No Nosy scaling | 6.63 | 47.64 | 59.47 | 181.07 | 294.81 |
| Previous current scaling | 8.60 | 43.24 | 45.81 | 77.55 | 175.20 |

The previous current scaling already helped the large 2050 reserves case
substantially, but it regressed the small historical case.

## Experiments

The experiment names in the table below use these meanings:

- **No Nosy scaling**: disabled `constraint_scaling` entirely. Constraints
  and objectives were sent to the solver in their natural JuMP/MOI form.
- **Previous current scaling**: the scaling implementation present before this
  investigation. Scalar affine rows were scaled, small terms were filtered, and
  the objective used the existing fixed scaling path.
- **Row scaling only, no objective scaling**: kept constraint row scaling but
  set the objective scale to 1. This isolated whether the improvement came from
  row conditioning or from scaling the economic objective coefficients.
- **Global variable scaling, factor 1000**: changed continuous operational and
  capacity variables so the solver variable represented `physical_value / 1000`,
  while expressions exposed by Nosy were multiplied back by 1000. This targeted
  large flow and capacity magnitudes, but it also changed bounds, starts, and
  many coefficients throughout the generated matrix.
- **Thresholded variable scaling, factor 1000**: a narrower variant of global
  variable scaling that tried to avoid scaling variables below a heuristic size
  threshold. The goal was to reduce collateral damage on already well-scaled
  variables.
- **Adaptive objective scaling**: selected the objective scaling factor from the
  largest objective coefficient, capped by `objectivescalingmax`, instead of
  using a fixed value. This was meant to make scaling less case-dependent.
- **Power-of-two row scaling**: row scale factors were rounded to the nearest
  power of two. This preserves binary floating-point values more exactly than an
  arbitrary decimal scale factor, but it does not place the largest coefficient
  exactly at `scalingtarget`.
- **Canonicalization**: combined duplicate terms in each scalar affine row before
  thresholding and scaling. For example, repeated terms on the same variable are
  merged into one coefficient, and exact cancellation can remove a variable from
  the row. This reduces matrix density and avoids scaling based on pre-merged
  duplicate coefficients.
- **Maxabs row scaling**: scaled each scalar affine row by
  `scalingtarget / max(abs(coefficients))`, after canonicalization,
  thresholding, and moving left-hand-side constants to the set. This makes the
  largest finite coefficient in each row close to `scalingtarget`.
- **Bridge cleanup**: kept the Nosy scaling bridge active but disabled row
  rescaling itself with `scalingmode = :none`. This still canonicalizes affine
  rows, filters tiny terms, shifts left-hand-side constants to the set, and can
  apply objective scaling.
- **Passthrough objective scaling**: kept the objective scaling/unscaling layer
  but left scalar affine constraints unchanged with `scalingmode = :passthrough`.
- **Selective extreme row scaling**: scaled only rows whose largest finite
  coefficient magnitude was outside `[1e-2, 1e2]`. Rows already in that band were
  left unscaled.
- **Objective scale 200**: multiplied scalar affine objective coefficients by
  200 before optimization, then unscaled reported objective values, objective
  bounds, and dual objective values for MOI/JuMP queries.
- **Objective scale auto**: selected objective scaling from the largest filtered
  objective coefficient, capped by `objectivescalingmax`.
- **Earlier final default rerun**: the previous retained configuration measured
  again after cleanup: canonicalization, maxabs row scaling, left-hand-side
  constant shifting, and objective scale 200.

| Experiment | historical | 2038 | 2050 | 2050 reserves | Total | Outcome |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| Row scaling only, no objective scaling | 8.51 | 39.29 | 44.37 | 97.61 | 189.78 | Rejected |
| Global variable scaling, factor 1000 | 8.36 | 36.96 | 63.13 | 83.98 | 192.44 | Rejected |
| Thresholded variable scaling, factor 1000 | 8.87 | 52.41 | 58.57 | 119.26 | 239.11 | Rejected |
| Adaptive objective scaling | 9.22 | 40.58 | 44.42 | 89.35 | 183.57 | Rejected |
| Power-of-two row scaling plus objective scale 200 | 9.23 | 39.39 | 41.70 | 83.63 | 173.96 | Mixed |
| Canonicalization plus maxabs row scaling plus objective scale 200 | 8.04 | 38.40 | 40.58 | 80.77 | 167.80 | Best measured explicit run |
| Canonicalization plus maxabs row scaling only | 8.51 | 37.73 | 43.01 | 84.86 | 174.10 | Rejected |
| Canonicalization plus power-of-two row scaling plus objective scale 200 | 8.92 | 37.30 | 40.69 | 83.96 | 170.87 | Not default |
| Earlier final default rerun | 8.70 | 37.97 | 38.54 | 86.48 | 171.69 | Superseded |

The earlier final default rerun was slightly slower than the best explicit run,
likely from normal solve-time noise, but it remained faster than the previous
current scaling reference on the aggregate metric. It was later superseded by
the objective-gated bridge-cleanup configuration below.

## Objective-Gated Experiments

From this point onward, candidates are treated as viable only if every benchmark
case has relative objective difference below `1e-5` versus the no-scaling
reference and the solver status matches. The following runs used that gate.

### Row-Mode Batch

This batch compared row-rescaling formulas while keeping objective scale 200.
All candidates passed the objective gate, but every row-rescaling mode was
slower than the same-run no-scaling reference.

| Experiment | historical | 2038 | 2050 | 2050 reserves | Total | Max objective rel diff | Gate | Outcome |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- |
| Anomalous no-scaling run, invalidated by recheck | 9.82 | 41.20 | 43.27 | 83.62 | 177.91 | reference | reference | Removed |
| Verified no-scaling recheck | 7.74 | 52.67 | 63.88 | 180.18 | 304.47 | reference | reference | Baseline |
| Current maxabs row scaling plus objective scale 200 | 6.68 | 47.37 | 55.95 | 177.29 | 287.30 | 9.15e-9 | PASS | Rejected |
| RHS-aware row max plus objective scale 200 | 6.59 | 47.17 | 56.17 | 170.18 | 280.11 | 9.15e-9 | PASS | Rejected |
| Geomean row scaling plus objective scale 200 | 6.67 | 49.87 | 55.99 | 172.77 | 285.29 | 9.15e-9 | PASS | Rejected |
| L2 row scaling plus objective scale 200 | 6.60 | 47.30 | 56.23 | 170.55 | 280.68 | 9.15e-9 | PASS | Rejected |
| Power-of-two row scaling plus objective scale 200 | 6.60 | 47.38 | 58.45 | 201.11 | 313.53 | 9.15e-9 | PASS | Rejected |

### Bridge-Cleanup Batch

This batch tested whether the useful part was row scaling or the other bridge
operations. `scalingmode = :none` keeps the bridge active but applies no row
scale factor. The best candidate was bridge cleanup with fixed objective scale
200.

| Experiment | historical | 2038 | 2050 | 2050 reserves | Total | Max objective rel diff | Gate | Outcome |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- |
| Anomalous same-run no-scaling reference, invalidated by recheck | 9.82 | 41.20 | 43.27 | 83.62 | 177.91 | reference | reference | Removed |
| Verified no-scaling recheck | 7.74 | 52.67 | 63.88 | 180.18 | 304.47 | reference | reference | Baseline |
| Bridge cleanup only, objective scale 1 | 7.79 | 41.41 | 42.09 | 92.67 | 183.96 | 5.55e-9 | PASS | Rejected |
| Bridge cleanup plus objective scale 200 | 8.73 | 40.51 | 37.58 | 86.51 | 173.33 | 5.55e-9 | PASS | Retained |
| Bridge cleanup plus automatic objective scale | 8.38 | 40.09 | 39.67 | 131.15 | 219.29 | 5.55e-9 | PASS | Rejected |
| Maxabs row scaling, objective scale 1 | 15.74 | 71.97 | 62.69 | 130.91 | 281.31 | 5.55e-9 | PASS | Rejected |

### Later Attempts Toward 120 Seconds

The target was tightened to a total solve time below 120 seconds, with the same
objective gate. Several larger levers were tested. None reached the target.

| Experiment | historical | 2038 | 2050 | 2050 reserves | Total | Max objective rel diff | Gate | Outcome |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- |
| Passthrough objective scale 1 | 12.61 | 59.36 | 49.88 | 137.35 | 259.20 | 6.85e-9 | PASS | Rejected |
| Passthrough objective scale 50 | 7.08 | 55.13 | 48.00 | not run | above 110 before reserves | 6.85e-9 | PASS before stop | Rejected |
| More aggressive coefficient sparsification, `expthreshold = 1e-8` | 13.80 | 99.03 | not run | not run | above 112 before 2050 | 2.54e-14 | PASS before stop | Rejected |
| Barrier tolerance `BarConvTol = 1e-6` | 6.17 | 52.21 | 39.62 | 114.86 | 212.87 | 1.57e-7 | PASS | Rejected |
| Barrier tolerance `BarConvTol = 1e-5` | 5.65 | 47.12 | 33.07 | 107.46 | 193.30 | 3.44e-6 | PASS | Rejected |
| Barrier tolerance `BarConvTol = 5e-5` | 4.83 | 41.77 | 29.84 | not run | failed before reserves | 1.63e-5 | FAIL | Rejected |
| Solver `ScaleFlag = 2` | 6.76 | 54.54 | 47.36 | not run | above 108 before reserves | 6.85e-9 | PASS before stop | Rejected |
| Selective extreme row scaling plus objective scale 200 | 8.45 | 42.98 | 38.18 | 81.86 | 171.47 | 4.52e-9 | PASS | Retained |

The selective extreme row-scaling run is the best objective-gated Nosy-side
candidate from this round, but it remains far above the requested 120-second
target. The experiments suggest that the 2050 reserves case, and to a lesser
extent the two forward-looking non-reserve cases, are dominated by more than
simple numerical scaling. Reaching 120 seconds likely requires broadening the
scope beyond scaling, for example model reformulation, reserve-constraint
reduction, decomposition/warm starts, or solver-algorithm policy changes.

## Retained Techniques

The retained changes are solver-side only:

- The scaling bridge remains active, and the default row scale mode is now
  `:extreme`, meaning only rows whose largest finite coefficient magnitude is
  outside `[1e-2, 1e2]` are multiplied by a row scale factor.
- Duplicate scalar affine terms are combined before thresholding and scaling.
  This can reduce row length and prevents duplicate terms from distorting the
  coefficient maximum used for row scaling.
- Left-hand-side constants are shifted to the constraint set before scaling,
  while MOI `ConstraintFunction` and `ConstraintSet` queries still reconstruct
  the original unscaled form.
  For example, `a'x + c <= b` is sent to the solver as `scale * a'x <=
  scale * (b - c)`, but external queries see the original unscaled constraint.
- Objective scaling is applied when the objective is set, currently defaulting
  to `objectivescaling = 200.0`.
  This preserves the old fixed-objective-scale behavior while making the scale
  explicit at objective setup time, after objective filtering.
- Reported objective quantities are unscaled for MOI/JuMP getters, including
  objective value, objective bound, and dual objective value.
- Other row-scaling modes remain available as opt-in experiments through
  `scalingmode = :passthrough`, `:none`, `:maxabs`, `:pow2`, `:rhsmax`,
  `:geomean`, or `:l2`.

## Rejected Techniques

Variable and capacity scaling was tried more invasively, including Stepwise
variables and fixed/variable/composed capacity variables. It did not improve
the aggregate metric:

- Best global variable-scaling run: 192.44 seconds total.
- Thresholded variable-scaling run: 239.11 seconds total.
- Both were worse than the previous current scaling reference of 175.20 seconds.

Those modifications were removed. The capacity and Stepwise files were restored
to their previous behavior, and the `variablescaling` option was removed.

The main lesson from these rejected runs is that column-like scaling is more
risky in Nosy than row/objective scaling. It touches modeling semantics earlier:
variable bounds, warm starts, fixed-capacity shortcuts, variable capacity
expressions, and every downstream constraint that reuses those expressions. In
the benchmark it helped some cases but worsened others enough to lose on the
aggregate metric, so it was not kept.

## Current Status

The current retained implementation is `scalingmode = :extreme` with fixed
objective scale 200. In the latest objective-gated run, it reached 171.47
seconds with a maximum relative objective difference of 4.52e-9, below the
required 1e-5 gate. This is still not close to the requested 120-second target.

## Reserves Seed Recheck

The 2050 reserves case was rerun three times with Gurobi seeds 11, 22, and 33
for the practical Pareto-front candidates reproducible from the current code.
All candidates passed the objective-difference gate against same-seed no
scaling.

| Candidate | Seed 11 | Seed 22 | Seed 33 | Mean | Min | Max | Mean objective rel diff |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| No scaling | 90.33 | 88.36 | 90.64 | 89.78 | 88.36 | 90.64 | 0.00e+00 |
| Bridge cleanup `:none` + obj200 | 84.06 | 89.99 | 80.80 | 84.95 | 80.80 | 89.99 | 3.54e-9 |
| Selective `:extreme` + obj200 | 87.22 | 86.42 | 88.23 | 87.29 | 86.42 | 88.23 | 4.15e-9 |
| `:maxabs` + obj200 | 92.94 | 87.42 | 90.47 | 90.28 | 87.42 | 92.94 | 4.62e-9 |
| `:pow2` + obj200 | 87.75 | 85.70 | 85.42 | 86.29 | 85.42 | 87.75 | 1.41e-9 |

On the reserves case alone, bridge cleanup with no row rescaling had the best
mean solve time. This suggests the earlier belief that the pre-work current
scaling reference was the best candidate is not supported on the repeated
reserves-only seed check.

## Result Equivalence Checks

The solve-time experiments were not all gated by an explicit result-equivalence
check. The main benchmark loop focused on `JuMP.solve_time`, solver status, and
the Nosy scaling tests. After the final retained configuration was selected, an
explicit no-scaling versus current-scaling check was run on the four benchmark
cases.

| Case | no-scaling status | current-scaling status | no-scaling objective | current-scaling objective | objective relative diff | extracted cost relative diff |
| --- | --- | --- | ---: | ---: | ---: | ---: |
| historical | OPTIMAL/FEASIBLE_POINT | OPTIMAL/FEASIBLE_POINT | 5.165619411848576e10 | 5.165619411847950e10 | 1.21e-13 | 1.48e-16 |
| 2038 | OPTIMAL/FEASIBLE_POINT | OPTIMAL/FEASIBLE_POINT | 5.579820650142720e10 | 5.579820650246133e10 | 1.85e-11 | 1.85e-11 |
| 2050 | OPTIMAL/FEASIBLE_POINT | OPTIMAL/FEASIBLE_POINT | 5.435159626179179e10 | 5.435160014804630e10 | 7.15e-8 | 7.15e-8 |
| 2050 reserves | OPTIMAL/FEASIBLE_POINT | OPTIMAL/FEASIBLE_POINT | 5.513923619936852e10 | 5.513923605280180e10 | 2.66e-9 | 2.66e-9 |

The retained scaling therefore preserved the benchmark objective to small
relative tolerances in these checks. The comparison is objective/cost based;
individual variable values were not compared because LPs can have alternate
optimal solutions with the same or numerically equivalent objective.

Focused tests passed after removing the variable/capacity scaling experiment:

- `test/optim/scaling.jl`: 43/43
- `test/optim/optimize.jl`: 21/21
- `test/optim/extract.jl`: 55/55
- `test/simulation/timeseries/variables.jl`: 14/14
- `test/system/components/behaviors/fixedcapacity.jl`: 20/20
- `test/system/components/behaviors/variablecapacity.jl`: 39/39
- `test/system/components/behaviors/variablecomposedcapacity.jl`: 26/26

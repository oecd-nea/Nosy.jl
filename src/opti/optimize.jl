"""
Optimization of systems.
"""

using JuMP: AffExpr, MIN_SENSE


# set objective to simulation based on snapshot and metric
# convention is: minimization
function set_objective!(s::Snapshot{AffExpr}, metric::Function)
    obj = metric(s)
    @assert obj isa VAL "`metric(s)` does not return an AffExpr or a Number"

    JuMP.set_objective(sim(s).model, MIN_SENSE, metric(s)) # NB JuMP function has no "!"
end
set_objective!(::Snapshot{Float64}, ::Function) = throw(AssertionError("This method should never be called"))

"""
    optimize!(s::Snapshot, metric::Function)
Optimize a Snapshot. This function does not return a Snapshot, but modifies the sim.model of `s`.
"""
function optimize!(s::Snapshot{AffExpr}, metric::Function)
    # if snapshot is not finalized yet, finalize it
    !is_finalized(s) && finalize!(s)

    set_objective!(s, metric)

    JuMP.optimize!(sim(s).model)
end
optimize!(::Snapshot{Float64}, ::Function) = throw(ArgumentError("Snapshot is already optimized"))
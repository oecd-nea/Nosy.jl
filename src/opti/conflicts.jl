import JuMP
import MathOptInterface as MOI

"""
    _conflicts(m)

Return the IIS as a vector of constraints in conflict of JuMP model `m`.
"""
function _conflicts(m::JuMP.Model)
    # following function is an aggregation of snippets from: https://jump.dev/JuMP.jl/stable/manual/solutions/#Conflicts
    compute_conflict!(m)
    if get_attribute(m, MOI.ConflictStatus()) == MOI.CONFLICT_FOUND
        list_of_conflicting_constraints = ConstraintRef[]
        for (F, S) in list_of_constraint_types(m)
            for con in all_constraints(m, F, S)
                if get_attribute(con, MOI.ConstraintConflictStatus()) == MOI.IN_CONFLICT
                    push!(list_of_conflicting_constraints, con)
                end
            end
        end
        return list_of_conflicting_constraints
    end
end

"""
    conflicts(s::Sim)
    conflicts(snapshot::Snapshot)

Return the vector of constraints in conflict (IIS) of the simulation.
If there are no conflicts, return nothing.
"""
function conflicts(s::Sim)
    c = _conflicts(s.model)
    isnothing(c) && @warn("No conflicts identified.")
    return c
end

conflicts(s::Snapshot) = conflicts(sim(s))

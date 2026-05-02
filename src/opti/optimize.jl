"""
Optimization of systems.
"""

using JuMP: GenericAffExpr, MIN_SENSE, all_variables, upper_bound

# remove terms with coefficients below a threshold in an expression
function filterexpression!(exp::GenericAffExpr, threshold::Number) # relative threshold
    if !isempty(exp.terms)
        _max = maximum(abs.(values(exp.terms)))
        sd = Int(round(-log10(threshold)))
        removed_terms = 0
        removed_term_names = String[]
        for (k,v) in exp.terms
            if abs(v) / _max < threshold
                exp.terms[k] = 0. # remove terms with relative cost inferior to threshold
                removed_terms += 1
                length(removed_term_names) < 10 && push!(removed_term_names, _variable_display_name(k))
            else
                exp.terms[k] = round(v, sigdigits=sd) # scale and round other terms
            end
        end
        drop_zeros!(exp) # remove zero terms in the objective
        if !iszero(removed_terms)
            @warn "Objective filtering removed $(removed_terms) terms below relative threshold $(threshold). First $(length(removed_term_names)) terms removed: $(join(removed_term_names, ", "))."
        end
    end
end
filterexpression!(exp::Number, threshold::Number) = nothing

function _variable_display_name(v)
    n = JuMP.name(v)
    return isempty(n) ? string(v) : n
end

# fix variables to zero when upper bound is below threshold
function cleanup_bounds!(s::Snapshot)
    threshold = sim(s).options[:boundthreshold]
    fixed_variables = 0
    fixed_variable_names = String[]
    for v in all_variables(s.sim.model)
        if !JuMP.is_fixed(v) && has_upper_bound(v) && has_lower_bound(v) && iszero(lower_bound(v)) && upper_bound(v) <= threshold
            length(fixed_variable_names) < 10 && push!(fixed_variable_names, _variable_display_name(v))
            set_upper_bound(v, 0)
            fix(v, 0, force=true)
            fixed_variables += 1
        end
    end
    if !iszero(fixed_variables)
        @warn "Optimization cleanup removed $(fixed_variables) variables by fixing them to zero because their upper bound was <= $(threshold). First $(length(fixed_variable_names)) variables fixed: $(join(fixed_variable_names, ", "))."
    end
end

# set objective to simulation based on an expression
# filter expression of objective using threshold
# convention is: minimization
# objectivetype can be :upper or :lower (in reference to bilevel optimization)
# both are equivalent for single objective optimization
function set_objective!(s::Snapshot{<:GenericAffExpr}, obj::Union{GenericAffExpr,Number}; objectivetype=:upper)
    threshold = sim(s).options[:objthreshold]
    obj isa Number && @warn "The optimization objective is a constant number, not an expression."

    filterexpression!(obj, threshold)

    if objectivetype == :upper
        @objective(uppermodel(sim(s)), Min, obj)
    elseif objectivetype == :lower
        @objective(lowermodel(sim(s)), Min, obj)
    else
        throw(ArgumentError("objectivetype must be either :upper or :lower"))
    end
end
set_objective!(::Snapshot{Float64}, ::Union{GenericAffExpr,Number}; objectivetype=:upper) = throw(AssertionError("Snapshot is already optimized"))

### Single-level problem ###

"""
    optimize!(snapshots, obj::Union{GenericAffExpr,Number})
Optimize snapshots sharing the same simulation. `snapshots` accepts either one `Snapshot` or an `AbstractVector` of `Snapshot`s. This function does not return a Snapshot, but modifies the underlying simulation model.
Thresholds are read from `sim(s).options`.
"""
function optimize!(s::Snapshot{AffExpr}, obj::Union{GenericAffExpr,Number})
    # if snapshot is not finalized yet, finalize it
    !is_finalized(s) && finalize!(s)
    set_objective!(s, obj)
    JuMP.optimize!(sim(s).model)
end
optimize!(::Snapshot{Float64}, ::Union{GenericAffExpr,Number}) = throw(ArgumentError("Snapshot is already optimized"))

# general case: multiple snapshots
function optimize!(snapshots::AbstractVector{<:Snapshot{AffExpr}}, obj::Union{GenericAffExpr,Number})
    isempty(snapshots) && throw(ArgumentError("Snapshot collection cannot be empty"))
    sref_sim = sim(first(snapshots))
    for s in snapshots
        sim(s) === sref_sim || throw(ArgumentError("unsupported optimization on snapshots with different simulations"))
        !is_finalized(s) && finalize!(s)
    end

    # all snapshots share the same simulation, using the first one is enough
    sref = first(snapshots)
    cleanup_bounds!(sref)
    set_objective!(sref, obj)

    JuMP.optimize!(sim(sref).model)
end


### Bilevel problem ###

"""
    optimize!(snapshots, lowerobj::Union{GenericAffExpr,Number}, upperobj::Union{GenericAffExpr,Number})
Optimize snapshots sharing the same simulation using bilevel optimization. `snapshots` accepts either one `Snapshot` or an `AbstractVector` of `Snapshot`s. This function does not return a Snapshot, but modifies the underlying simulation model.
Thresholds are read from `sim(s).options`.
"""
function optimize!(s::Snapshot{<:GenericAffExpr}, lowerobj::Union{GenericAffExpr,Number}, upperobj::Union{GenericAffExpr,Number})
    # if snapshot is not finalized yet, finalize it
    !is_finalized(s) && finalize!(s)
    cleanup_bounds!(s)
    set_objective!(s, lowerobj, objectivetype=:lower)
    set_objective!(s, upperobj, objectivetype=:upper)
    JuMP.optimize!(sim(s).model)
end
optimize!(::Snapshot{Float64}, ::Union{GenericAffExpr,Number}, ::Union{GenericAffExpr,Number}) = throw(ArgumentError("Snapshot is already optimized"))

# general case: multiple snapshots (bilevel)
function optimize!(snapshots::AbstractVector{<:Snapshot{<:GenericAffExpr}}, lowerobj::Union{GenericAffExpr,Number}, upperobj::Union{GenericAffExpr,Number})
    isempty(snapshots) && throw(ArgumentError("Snapshot collection cannot be empty"))
    sref_sim = sim(first(snapshots))
    for s in snapshots
        sim(s) === sref_sim || throw(ArgumentError("unsupported optimization on snapshots with different simulations"))
        !is_finalized(s) && finalize!(s)
    end

    # all snapshots share the same simulation, using the first one is enough
    sref = first(snapshots)
    cleanup_bounds!(sref)

    set_objective!(sref, lowerobj, objectivetype=:lower)
    set_objective!(sref, upperobj, objectivetype=:upper)

    JuMP.optimize!(sim(sref).model)
end

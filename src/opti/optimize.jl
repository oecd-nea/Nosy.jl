"""
Optimization of systems.
"""

using JuMP: GenericAffExpr, MIN_SENSE, all_variables, upper_bound

# remove terms with coefficients below a threshold in an expression
function filterexpression!(exp::GenericAffExpr, threshold::Number) # relative threshold
    if !isempty(exp.terms)
        _max = maximum(abs.(values(exp.terms)))
        sd = Int(round(-log10(threshold)))
        for (k,v) in exp.terms
            if abs(v) / _max < threshold
                exp.terms[k] = 0. # remove terms with relative cost inferior to threshold
            else
                exp.terms[k] = round(v, sigdigits=sd) # scale and round other terms
            end
        end
        drop_zeros!(exp) # remove zero terms in the objective
    end
end
filterexpression!(exp::Number, threshold::Number) = nothing

# fix variables to zero when upper bound is below threshold
function cleanup_bounds!(s::Snapshot, threshold::Number)
    for v in all_variables(s.sim.model)
        if has_upper_bound(v) && has_lower_bound(v) && iszero(lower_bound(v)) && upper_bound(v) <= threshold
            set_upper_bound(v, 0)
            fix(v, 0, force=true)
        end
    end
end

# set objective to simulation based on snapshot and metric
# filter expression of objective using threshold
# convention is: minimization
# objectivetype can be :upper or :lower (in reference to bilevel optimization)
# both are equivalent for single objective optimization
function set_objective!(s::Snapshot{<:GenericAffExpr}, metric::Function; threshold=1E-15, objectivetype=:upper)
    obj = metric(s)

    obj isa Number && @warn "The optimization objective is a constant number, not an expression."

    if !(obj isa VAL) 
        throw(AssertionError("`metric(s)` does not return an GenericAffExpr or a Number"))
    end

    filterexpression!(obj, threshold)

    if objectivetype == :upper
        @objective(uppermodel(sim(s)), Min, obj)
    elseif objectivetype == :lower
        @objective(lowermodel(sim(s)), Min, obj)
    else
        throw(ArgumentError("objectivetype must be either :upper or :lower"))
    end
end
set_objective!(::Snapshot{Float64}, ::Function, threshold=1E-15) = throw(AssertionError("Snapshot is already optimized"))



### Single-level problem ###

"""
    optimize!(s::Snapshot{AffExpr}, metric::Function; expthreshold=1E-9, boundthreshold=1E-3)
Optimize a Snapshot. This function does not return a Snapshot, but modifies the sim.model of `s`.
Keyword arguments:
  * expthreshold: relative threshold for costs in the objective expression
  * boundthreshold: absolute threshold for upper bounds of all variables (if upper bound is lower: fix variable @ zero)
"""
function optimize!(s::Snapshot{AffExpr}, metric::Function; expthreshold=1E-9, boundthreshold=1E-3)
    # if snapshot is not finalized yet, finalize it
    !is_finalized(s) && finalize!(s)

    cleanup_bounds!(s, boundthreshold)
    set_objective!(s, metric, threshold=expthreshold)

    JuMP.optimize!(sim(s).model)
end
optimize!(::Snapshot{Float64}, ::Function; threshold=1E-9, boundthreshold=1E-3) = throw(ArgumentError("Snapshot is already optimized"))


### Bilevel problem ###

"""
    optimize!(s::Snapshot{<:GenericAffExpr}, lowermetric::Function, uppermetric::Function; expthreshold=1E-9, boundthreshold=1E-3)
Optimize a Snapshot using bilevel optimization. This function does not return a Snapshot, but modifies the sim.model of `s`.
Keyword arguments:
  * expthreshold: relative threshold for costs in the objective expression
  * boundthreshold: absolute threshold for upper bounds of all variables (if upper bound is lower: fix variable @ zero)
"""
function optimize!(s::Snapshot{<:GenericAffExpr}, lowermetric::Function, uppermetric::Function; expthreshold=1E-9, boundthreshold=1E-3)
    # if snapshot is not finalized yet, finalize it
    !is_finalized(s) && finalize!(s)

    cleanup_bounds!(s, boundthreshold)

    set_objective!(s, lowermetric, threshold=expthreshold, objectivetype=:lower)
    set_objective!(s, uppermetric, threshold=expthreshold, objectivetype=:upper)

    JuMP.optimize!(sim(s).model)
end
optimize!(::Snapshot{Float64}, ::Function, ::Function; threshold=1E-9, boundthreshold=1E-3) = throw(ArgumentError("Snapshot is already optimized"))
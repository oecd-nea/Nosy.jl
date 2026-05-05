using JuMP, BilevelJuMP

# for a single-level mdodel, Lower and Upper levels are the same
Nosy.Lower(m::JuMP.Model) = m
Nosy.Upper(m::JuMP.Model) = m

_model(m::JuMP.Model) = m
_model(::BilevelJuMP.BilevelModel) = throw(AssertionError("Use lowermodel or uppermodel to access the models of a bilevel simulation."))

issolvedandfeasible(::JuMP.AbstractModel; kwargs...) = throw(AssertionError("unknown model type"))
issolvedandfeasible(model::JuMP.Model; kwargs...) = JuMP.is_solved_and_feasible(model; kwargs...)
issolvedandfeasible(model::BilevelJuMP.InnerBilevelModel; kwargs...) = issolvedandfeasible(BilevelJuMP.bilevel_model(model); kwargs...)

function issolvedandfeasible(
    model::BilevelJuMP.BilevelModel;
    dual::Bool = false,
    allow_local::Bool = true,
    allow_almost::Bool = false,
    result::Int = 1,
)
    if result != 1
        throw(ArgumentError("result must be 1 for BilevelModel"))
    end
    status = JuMP.termination_status(model)
    ret =
        (status == JuMP.OPTIMAL) ||
        (allow_local && (status == JuMP.LOCALLY_SOLVED)) ||
        (allow_almost && (status == JuMP.ALMOST_OPTIMAL)) ||
        (allow_almost && allow_local && (status == JuMP.ALMOST_LOCALLY_SOLVED))
    if ret
        primal = JuMP.primal_status(model)
        ret &=
            (primal == JuMP.FEASIBLE_POINT) ||
            (allow_almost && (primal == JuMP.NEARLY_FEASIBLE_POINT))
    end
    if ret && dual
        throw(ArgumentError("dual=true is not supported for BilevelModel; query dual status on Upper(model) or Lower(model) instead"))
    end
    return ret
end

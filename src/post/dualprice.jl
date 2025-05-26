"""
Evaluation of dual price.
"""

using JuMP: has_duals

# extract dual price from node constraint
function _dualprice(a::DualPrice{<:GenericAffExpr})
    e = DualPrice{Float64}(nothing)
    if !isnothing(a.val)
        e.val = dual.(a.val)
    end
    return e
end
_dualprice(a::DualPrice{Float64}) = a.val

_dualprice(::Nothing, ::Sim) = nothing
_dualprice(a::AbstractVector{<:Number}, s::Sim) = Stepwise(a, s.mesh)

_dualprice(::Node{<:GenericAffExpr}) = throw(AssertionError("Cannot evaluate dual price: model is not optimized"))
_dualprice(n::Node{Float64}) = _dualprice(n.dualprice.val, sim(n))

"""
    dualprice(n::Node)
Return the dual price associated with node `n`
"""
function dualprice(n::Node)
    if has_duals(sim(n).model)
        return _dualprice(n)
    else
        if is_solved_and_feasible(sim(n).model)
            return Stepwise(-Inf, sim(n).mesh) # set price to fallback value (-Inf) at all times
        else
            throw(AssertionError("Cannot evaluate dual price: duals are not available"))
        end
    end
end
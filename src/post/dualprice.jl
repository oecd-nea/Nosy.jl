"""
Evaluation of dual price.
"""

using JuMP: dual, has_duals, owner_model
using ArgCheck: ArgumentError

# extract dual price from node constraint
function _dualprice(a::DualPrice{<:GenericAffExpr})
    e = DualPrice{Float64}(nothing)
    if !isnothing(a.val)
        if isempty(a.val)
            e.val = Float64[]
        else
            m = owner_model(first(a.val))
            if has_duals(m)
                e.val = dual.(a.val)
            elseif issolvedandfeasible(m)
                @warn "Duals are not available - setting price to -Inf"
                e.val = fill(-Inf, length(a.val))
            else
                throw(ArgumentError("Cannot evaluate dual price: duals are not available"))
            end
        end
    end
    return e
end
_dualprice(a::DualPrice{Float64}) = a.val

_dualprice(::Nothing, ::Sim) = nothing
_dualprice(a::AbstractVector{<:Number}, s::Sim) = Stepwise(a, s.mesh)

function _dualprice(n::Node{<:GenericAffExpr})
    if isnothing(n.dualprice.val) && !issolvedandfeasible(sim(n).model)
        throw(ArgumentError("Cannot evaluate dual price: model is not optimized"))
    end
    return _dualprice(_dualprice(n.dualprice).val, sim(n))
end
_dualprice(n::Node{Float64}) = _dualprice(n.dualprice.val, sim(n))

"""
    dualprice(n::Node)
Return the dual price associated with node `n`
"""
dualprice(n::Node{Float64}) = _dualprice(n)

dualprice(n::Node) = _dualprice(n)

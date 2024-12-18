"""
Evaluation of dual price.
"""

# extract dual price from node constraint
function _dualprice(a::DualPrice{AffExpr})
    e = DualPrice{Float64}(nothing)
    if !isnothing(a.val)
        e.val = dual.(a.val)
    end
    return e
end
_dualprice(a::DualPrice{Float64}) = a.val

_dualprice(::Nothing, ::Sim) = nothing
_dualprice(a::AbstractVector{<:Number}, s::Sim) = Stepwise(a, s.mesh)

_dualprice(::Node{AffExpr}) = throw(AssertionError("Cannot evaluate dual price: model is not optimized"))
_dualprice(n::Node{Float64}) = _dualprice(n.dualprice.val, sim(n))

"""
    dualprice(n::Node)
Return the dual price associated with node `n`
"""
dualprice(n::Node) = _dualprice(n)
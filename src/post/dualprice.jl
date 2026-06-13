"""
Evaluation of dual price.
"""

using JuMP: dual, has_duals, owner_model
using ArgCheck: ArgumentError

# extract dual price from node constraint
function _dualprice(a::SavedDualPrice{<:GenericAffExpr})
    e = DualPrice{Float64}(nothing)
    if !isnothing(a.constraints)
        if isempty(a.constraints)
            e.values = nothing
        else
            m = owner_model(first(a.constraints))
            if has_duals(m)
                e.values = Float64.(dual.(a.constraints))
            elseif issolvedandfeasible(m)
                @warn "Duals are not available - setting price to -Inf"
                e.values = fill(-Inf, length(a.constraints))
            else
                throw(ArgumentError("Cannot evaluate dual price: duals are not available"))
            end
        end
    end
    return e
end
_dualprice(a::DualPrice{Float64}) = a.values

_dualprice(::Nothing, ::Sim) = nothing
_dualprice(::Nothing, ::TimeMesh) = nothing
_dualprice(::Nothing, ::Node) = nothing
_dualprice(a::AbstractVector{<:Number}, s::Sim) = _dualprice(a, s.mesh)
function _dualprice(a::AbstractVector{<:Number}, m::TimeMesh)
    raw = Stepwise(a, m)
    weights = Stepwise([integrationweight(m, i) for i in eachstep(m)], m)
    return raw ./ weights
end

function _dualprice(a::AbstractVector{<:Number}, n::Node)
    return _dualprice(a, mesh(n))
end

function _dualprice(n::Node{<:GenericAffExpr})
    if isnothing(n.dualprice.constraints) && !issolvedandfeasible(sim(n).model)
        throw(ArgumentError("Cannot evaluate dual price: model is not optimised"))
    end
    return _dualprice(_dualprice(n.dualprice).values, n)
end
_dualprice(n::Node{Float64}) = _dualprice(n.dualprice.values, n)

_hourlydualprice(::Nothing) = nothing
_hourlydualprice(a::Stepwise{Float64}) = Hourly(a)

"""
    dualprice(n::Node)

Return the dual price associated with node `n`.
"""
dualprice(n::Node) = _hourlydualprice(_dualprice(n))

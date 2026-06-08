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
function _dualprice(a::AbstractVector{<:Number}, s::Sim)
    raw = Stepwise(a, s.mesh)
    weights = Stepwise([_dualprice_weight(s.mesh, i) for i in eachstep(s)], s.mesh)
    return raw ./ weights
end

function _dualprice_weight(m::TimeMesh, i::Int)
    if iscircular(m)
        return Float64((weight(m, i - 1) + weight(m, i)) / 2)
    elseif nsteps(m) == 1
        # Open one-point meshes have no interval in sum(::Stepwise). Keep a
        # positive normalization factor so dual-price evaluation remains finite.
        return Float64(weight(m, i))
    elseif i == 1
        return Float64(weight(m, i) / 2)
    elseif i == nsteps(m)
        return Float64(weight(m, i - 1) / 2)
    else
        return Float64((weight(m, i - 1) + weight(m, i)) / 2)
    end
end

function _dualprice(n::Node{<:GenericAffExpr})
    if isnothing(n.dualprice.constraints) && !issolvedandfeasible(sim(n).model)
        throw(ArgumentError("Cannot evaluate dual price: model is not optimised"))
    end
    return _dualprice(_dualprice(n.dualprice).values, sim(n))
end
_dualprice(n::Node{Float64}) = _dualprice(n.dualprice.values, sim(n))

_hourlydualprice(::Nothing) = nothing
_hourlydualprice(a::Stepwise{Float64}) = Hourly(a)

"""
    dualprice(n::Node)

Return the dual price associated with node `n`.
"""
dualprice(n::Node) = _hourlydualprice(_dualprice(n))

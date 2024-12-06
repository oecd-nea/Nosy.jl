# perform the sum of the metric over the component
# bs is the list of candidate behaviors compatible with the metric
function sumofmetric(c::Component{T}, B, metric) where T
    bs = behaviors(c, B)
    if isempty(bs)
        return 0. # not type-stable, but prevents allocation of AffExpr(0.) each time a component has not the behavior, which is most of the time
    else
        return sum(metric(b)::T for b in bs)
    end
end

_metrictype(::AbstractBehavior) = error("not implemented")

sumofmetric(c::Component{T}, B, metric, type::Symbol) where T = sum([metric(b)::T for b in behaviors(c, B) if _metrictype(b) == type], init=0.)
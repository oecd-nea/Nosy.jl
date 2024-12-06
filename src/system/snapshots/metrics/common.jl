"""
Cost metrics for snapshots.
"""

function _applymetric(s::Snapshot, cname::String, metric::Function)
    @assert hascomponent(s, cname) "Snapshot does not contain component $cname"
    return metric(getcomponent(s,cname))
end

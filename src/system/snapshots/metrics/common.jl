"""
Cost metrics for snapshots.
"""

function _applymetric(s::Snapshot, cname::String, metric::Function)
    if !hascomponent(s, cname) 
        throw(AssertionError("Snapshot does not contain component $cname"))
    end
    return metric(getcomponent(s,cname))
end

function _applymetric(s::Snapshot, cname::String, metric::Function, type::Symbol)
    if !hascomponent(s, cname)
        throw(AssertionError("Snapshot does not contain component $cname"))
    end
    return metric(getcomponent(s, cname), type)
end
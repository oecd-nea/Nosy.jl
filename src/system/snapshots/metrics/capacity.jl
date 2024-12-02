"""
Capacity metrics for snapshots.
"""

"""
    capacity(s::Snapshot, cname::String)
Return the capacity of component with name `cname` from snapshot `s`.
If the component has no capacity, return zero.
Throw an error is there is no component with name `cname` in `s`.
"""
function capacity(s::Snapshot, cname::String)
    @assert hascomponent(s, cname) "Snapshot does not contain component $cname"
    return capacity(getcomponent(s, cname))
end
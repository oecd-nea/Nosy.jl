"""
Capacity metrics for snapshots.
"""

"""
    capacity(s::Snapshot, cname::String)
Return the capacity of component with name `cname` from snapshot `s`.
If the component has no capacity, return zero.
Throw an error is there is no component with name `cname` in `s`.
"""
capacity(s::Snapshot, cname::String) = _applymetric(s, cname, capacity)
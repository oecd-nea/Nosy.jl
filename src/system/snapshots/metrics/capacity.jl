"""
Capacity metrics for snapshots.
"""

"""
    capacity(s::Snapshot, cname::String; multiplier::Bool=false)

Return the capacity of component with name `cname` from snapshot `s`.
If `multiplier` is true, return the capacity multiplied with the matching capacity multiplier (same port) if it exists.
If the component has no capacity, return zero.
Throw an error if there is no component with name `cname` in `s`.
"""
capacity(s::Snapshot, cname::String; multiplier::Bool=false) = _applymetric(s, cname, x->capacity(x, multiplier=multiplier))
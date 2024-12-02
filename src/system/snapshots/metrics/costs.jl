"""
Cost metrics for snapshots.
"""

"""
    overnightcost(s::Snapshot, cname::String)
Return the overnight cost of Component with name `cname` in Snapshot `s`.
If the component has no overnight cost, return zero.
Throw an error is there is no component with name `cname` in `s`.
"""
function overnightcost(s::Snapshot, cname::String)
    @assert hascomponent(s, cname) "Snapshot does not contain component $cname"
    return overnightcost(getcomponent(s, cname))
end

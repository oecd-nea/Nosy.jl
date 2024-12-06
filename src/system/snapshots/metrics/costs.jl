"""
    overnightcost(s::Snapshot, cname::String)
Return the overnight cost of Component with name `cname` in Snapshot `s`.
If the component has no overnight cost, return zero.
Throw an error is there is no component with name `cname` in `s`.
"""
overnightcost(s::Snapshot, cname::String) = _applymetric(s, cname, overnightcost)
overnightcost(s::Snapshot, cname::String, type::Symbol) = _applymetric(s, cname, overnightcost, type)


"""
    variablecost(s::Snapshot, cname::String)
Return the variable cost of Component with name `cname` in Snapshot `s`.
If the component has no variable cost, return zero.
Throw an error is there is no component with name `cname` in `s`.
"""
variablecost(s::Snapshot, cname::String) = _applymetric(s, cname, variablecost)
variablecost(s::Snapshot, cname::String, type::Symbol) = _applymetric(s, cname, variablecost, type)

"""
    cost(s::Snapshot, cname::String)
Return the cost of Component with name `cname` in Snapshot `s`.
If the component has no cost, return zero.
Throw an error is there is no component with name `cname` in `s`.
"""
cost(s::Snapshot, cname::String) = _applymetric(s, cname, cost)
cost(s::Snapshot, cname::String, type::Symbol) = _applymetric(s, cname, cost, type)
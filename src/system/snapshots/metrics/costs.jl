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

"""
    overnightcost(s::Snapshot)
Return the overnight cost of Snapshot `s` as the sum of overnight costs of the components of `s`.
"""
overnightcost(s::Snapshot) = sum(overnightcost(s, cname) for cname in keys(s.components))
overnightcost(s::Snapshot, type::Symbol) = sum(overnightcost(s, cname, type) for cname in keys(s.components))

"""
    variablecost(s::Snapshot)
Return the variable cost of Snapshot `s` as the sum of variable costs of the components of `s`.
"""
variablecost(s::Snapshot) = sum(variablecost(s, cname) for cname in keys(s.components))
variablecost(s::Snapshot, type::Symbol) = sum(variablecost(s, cname, type) for cname in keys(s.components))

"""
    cost(s::Snapshot)
Return the cost of the Snapshot, defined as the sum of the costs of the components of the Snapshot.
"""
cost(s::Snapshot) = sum(cost(s, cname) for cname in keys(s.components))
cost(s::Snapshot, type::Symbol) = sum(cost(s, cname, type) for cname in keys(s.components))

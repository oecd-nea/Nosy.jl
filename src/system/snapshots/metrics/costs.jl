"""
    fixedcost(s::Snapshot, cname::String)
Return the fixed cost of Component with name `cname` in Snapshot `s`.
If the component has no fixed cost, return zero.
Throw an error is there is no component with name `cname` in `s`.
"""
fixedcost(s::Snapshot, cname::String) = _applymetric(s, cname, fixedcost)
fixedcost(s::Snapshot, cname::String, type::Symbol) = _applymetric(s, cname, fixedcost, type)


"""
    variablecost(s::Snapshot, cname::String)
Return the variable cost of Component with name `cname` in Snapshot `s`.
If the component has no variable cost, return zero.
Throw an error is there is no component with name `cname` in `s`.
"""
variablecost(s::Snapshot, cname::String) = _applymetric(s, cname, variablecost)
variablecost(s::Snapshot, cname::String, type::Symbol) = _applymetric(s, cname, variablecost, type)

"""
    noloadcost(s::Snapshot, cname::String)
Return the no-load cost of Component with name `cname` in Snapshot `s`.
If the component has no no-load cost, return zero.
Throw an error is there is no component with name `cname` in `s`.
"""
noloadcost(s::Snapshot, cname::String) = _applymetric(s, cname, noloadcost)
noloadcost(s::Snapshot, cname::String, type::Symbol) = _applymetric(s, cname, noloadcost, type)

"""
    cost(s::Snapshot, cname::String)
Return the cost of Component with name `cname` in Snapshot `s`.
If the component has no cost, return zero.
Throw an error is there is no component with name `cname` in `s`.
"""
cost(s::Snapshot, cname::String) = _applymetric(s, cname, cost)
cost(s::Snapshot, cname::String, type::Symbol) = _applymetric(s, cname, cost, type)

"""
    fixedcost(s::Snapshot)
Return the fixed cost of Snapshot `s` as the sum of fixed costs of the components of `s`.
"""
fixedcost(s::Snapshot) = sum(fixedcost(s, cname) for cname in keys(s.components))
fixedcost(s::Snapshot, type::Symbol) = sum(fixedcost(s, cname, type) for cname in keys(s.components))

"""
    variablecost(s::Snapshot)
Return the variable cost of Snapshot `s` as the sum of variable costs of the components of `s`.
"""
variablecost(s::Snapshot) = sum(variablecost(s, cname) for cname in keys(s.components))
variablecost(s::Snapshot, type::Symbol) = sum(variablecost(s, cname, type) for cname in keys(s.components))

"""
    noloadcost(s::Snapshot)
Return the no-load cost of Snapshot `s` as the sum of no-load costs of the components of `s`.
"""
noloadcost(s::Snapshot) = sum(noloadcost(s, cname) for cname in keys(s.components))
noloadcost(s::Snapshot, type::Symbol) = sum(noloadcost(s, cname, type) for cname in keys(s.components))

"""
    cost(s::Snapshot)
Return the cost of the Snapshot, defined as the sum of the costs of the components of the Snapshot.
"""
cost(s::Snapshot) = sum(cost(s, cname) for cname in keys(s.components))
cost(s::Snapshot, type::Symbol) = sum(cost(s, cname, type) for cname in keys(s.components))



# return a Vector{Symbol} containing all the user-defined cost types of the Snapshot
function _costtypes(s::Snapshot)
    ctypes = Vector{Symbol}(undef,0)
    for (_,c) in s.components
        for b in getbehaviors(c, AbstractCostBehavior)
            ctype = _costtype(b)
            if !(ctype in ctypes)
                push!(ctypes, ctype)
            end
        end
    end
    return sort(ctypes) # sort to maintain same order across different snapshots
end
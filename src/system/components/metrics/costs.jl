_metrictype(c::AbstractCostBehavior) = _costtype(c)

"""
    fixedcost(c::Component)
Return the fixed cost of Component `c` as the sum of its fixed costs.
If the component has no fixed cost, return zero.
"""
fixedcost(c::Component{T}) where T = sumofmetric(c, FixedCostBehavior{T}, _fixedcost)

fixedcost(c::Component{T}, type::Symbol) where T = sumofmetric(c, FixedCostBehavior{T}, _fixedcost, type)

"""
    variablecost(c::Component)
Return the variable cost of Component `c` as the sum of its variable costs.
If the component has no variable cost, return zero.
"""
variablecost(c::Component{T}) where T = sumofmetric(c, VariableCostBehavior{T}, _variablecost)

variablecost(c::Component{T}, type::Symbol) where T = sumofmetric(c, VariableCostBehavior{T}, _variablecost, type)

const COST_COMPONENT_METRICS = (fixedcost, variablecost,)

"""
    cost(c::Component)
Return the cost of Component `c`.
"""
cost(c::Component) = sum(f(c) for f in COST_COMPONENT_METRICS)

cost(c::Component, type::Symbol) = sum(f(c, type) for f in COST_COMPONENT_METRICS)
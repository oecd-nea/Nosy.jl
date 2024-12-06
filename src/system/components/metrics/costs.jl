_metrictype(c::AbstractCostBehavior) = _costtype(c)

"""
    overnightcost(c::Component)
Return the overnight cost of Component `c` as the sum of its overnight costs.
If the component has no overnight cost, return zero.
"""
overnightcost(c::Component{T}) where T = sumofmetric(c, OvernightCostBehavior{T}, _overnightcost)

overnightcost(c::Component{T}, type::Symbol) where T = sumofmetric(c, OvernightCostBehavior{T}, _overnightcost, type)

"""
    variablecost(c::Component)
Return the variable cost of Component `c` as the sum of its variable costs.
If the component has no variable cost, return zero.
"""
variablecost(c::Component{T}) where T = sumofmetric(c, VariableCostBehavior{T}, _variablecost)

variablecost(c::Component{T}, type::Symbol) where T = sumofmetric(c, VariableCostBehavior{T}, _variablecost, type)

const COST_COMPONENT_METRICS = (overnightcost, variablecost,)

"""
    cost(c::Component)
Return the cost of Component `c`.
"""
cost(c::Component) = sum(f(c) for f in COST_COMPONENT_METRICS)

cost(c::Component, type::Symbol) = sum(f(c, type) for f in COST_COMPONENT_METRICS)
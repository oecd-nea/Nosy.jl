_metrictype(c::AbstractCostBehavior) = _costtype(c)

"""
    fixedcost(c::Component)
Return the fixed cost of Component `c`.
If the component has no fixed cost, return zero.
"""
fixedcost(c::Component{T}) where T = sumofmetric(c, FixedCostBehavior{T}, _fixedcost)

"""
    fixedcost(c::Component, type::Symbol)
Return fixed cost cost of type `type` of Component `c`.
If the component has no fixed cost, return zero.
"""
fixedcost(c::Component{T}, type::Symbol) where T = sumofmetric(c, FixedCostBehavior{T}, _fixedcost, type)

"""
    variablecost(c::Component)
Return the variable cost of Component `c`.
If the component has no variable cost, return zero.
"""
variablecost(c::Component{T}) where T = sumofmetric(c, VariableCostBehavior{T}, _variablecost)

"""
    variablecost(c::Component, type::Symbol)
Return variable cost cost of type `type` of Component `c`.
If the component has no variable cost, return zero.
"""
variablecost(c::Component{T}, type::Symbol) where T = sumofmetric(c, VariableCostBehavior{T}, _variablecost, type)

"""
    noloadcost(c::Component)
Return the no-load cost of Component `c`.
If the component has no no-load cost, return zero.
"""
noloadcost(c::Component{T}) where T = sumofmetric(c, NoLoadCostBehavior{T}, _noloadcost)

"""
    noloadcost(c::Component, type::Symbol)
Return the no-load cost of type `type` of Component `c`.
If the component has no no-load cost, return zero.
"""
noloadcost(c::Component{T}, type::Symbol) where T = sumofmetric(c, NoLoadCostBehavior{T}, _noloadcost, type)

"""
    startupcost(c::Component)
Return the startup cost of Component `c`.
If the component has no startup cost, return zero.
"""
startupcost(c::Component{T}) where T = sumofmetric(c, StartupCostBehavior{T}, _startupcost)

"""
    startupcost(c::Component, type::Symbol)
Return the startup cost of type `type` of Component `c`.
If the component has no startup cost, return zero.
"""
startupcost(c::Component{T}, type::Symbol) where T = sumofmetric(c, StartupCostBehavior{T}, _startupcost, type)

# dict containing the cost metrics (other than costs)
# these metrics must be such that their sum is equal to cost
const COST_COMPONENT_METRICS = Dict(
    variablecost => "variable cost",
    fixedcost => "fixed cost",
    noloadcost => "no-load cost",
    startupcost => "startup cost",
)


# total cost is defined as the sum of the costs above

"""
    cost(c::Component)
Return the cost of Component `c`.
"""
cost(c::Component) = sum(f(c) for (f,_) in COST_COMPONENT_METRICS)

"""
    cost(c::Component)
Return the cost of type `type` of Component `c`.
"""
cost(c::Component, type::Symbol) = sum(f(c, type) for (f,_) in COST_COMPONENT_METRICS)
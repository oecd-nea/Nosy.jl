"""
Abstract types for cost behaviors.
"""

abstract type AbstractCostBehaviorData <: AbstractBehaviorData end

abstract type AbstractCostBehavior{T} <: AbstractRegularBehavior{T} end


"""
Cost behavior interface.

Concrete types of AbstractCostBehavior must implement the following functions:
  * _costtype(c::AbstracCostBehavior)::Symbol -> return the cost type e.g. :overnight, :vom, :fuel etc.
"""

_costtype(::AbstractBehavior) = error("not implemented")
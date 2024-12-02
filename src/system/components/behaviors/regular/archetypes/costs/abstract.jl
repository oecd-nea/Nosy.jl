"""
Abstract types for cost behaviors.
"""

abstract type AbstractCostBehaviorData <: AbstractBehaviorData end

abstract type AbstractCostBehavior{T} <: AbstractRegularBehavior{T} end
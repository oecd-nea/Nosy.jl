"""
Abstract capacity behaviors.
"""

# abstract type for capacity behavior data
abstract type AbstractCapacityData <: AbstractRegularBehaviorData end

# abstract type for capacity behavior
abstract type AbstractCapacityBehavior{T} <: AbstractRegularBehavior{T} end
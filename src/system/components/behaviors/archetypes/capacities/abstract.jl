"""
Abstract capacity behaviors.
"""

# abstract type for capacity behavior data
abstract type AbstractCapacityData <: AbstractBehaviorData end

# abstract type for capacity behavior
abstract type AbstractCapacityBehavior{T} <: AbstractBehavior{T} end
"""
Abstract capacity behaviors.
"""

# abstract type for capacity behavior data
abstract type AbstractCapacityData <: AbstractRegularBehaviorData end

# abstract type for capacity behavior
abstract type AbstractCapacityBehavior{T} <: AbstractRegularBehavior{T} end


"""
AbstractCapacityBehavior interface:
  * implement _portname(b::AbstractCapacityBehavior) -> return the associated port name
  * implement _modifier(b::AbstractCapacityBehavior) -> return the associated modifier
"""
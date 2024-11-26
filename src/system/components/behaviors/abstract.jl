"""
Abstract types for behavior data and behaviors.
"""

"""
AbstractBehaviorData: supertype for behavior data.
Behavior data encapsulates the data required to generate behaviors.
It is directly constructed by the user call to the constructor.
"""

abstract type AbstractBehaviorData end


"""
AbstractBehavior: supertype for behaviors.
Behaviors themselves are not constructed by the user. 
The constructor is called by the component constructor instead.
"""

abstract type AbstractBehavior{T} <: AbstractElement{T} end


"""
AbstractBehaviorData interface:
  * implement buildbehavior(c::AbstractComponent, cname::String, b::AbstractBehaviorData) -> return a AbstractBehavior
"""

buildbehavior(::AbstractComponent, ::String, ::AbstractBehavior) = error("Not implemented")


"""
AbstractBehavior interface:
  * implement behaviorname(b::AbstractBehaviorModel) -> return a String
  * implement _apply_constraints!(c::AbstractComponent, b::AbstractBehavior) -> apply constraints to component, return nothing
"""

behaviorname(::AbstractBehavior) = error("Not implemented")
_apply_constraints!(::AbstractComponent, ::AbstractBehavior) = error("Not implemented")
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


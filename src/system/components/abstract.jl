"""
Abstract types for components, models, and behaviors.
"""

abstract type AbstractComponent{T} <: AbstractElement{T} end


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
Behaviors fall into 2 categories:
  * regular behaviors: constrain or enrich the flows of a model
  * joint flows: add a flow to the component that is not present in the model
"""



"""
Abstract types for regular behaviors.
"""

abstract type AbstractRegularBehaviorData <: AbstractBehaviorData end

abstract type AbstractRegularBehavior{T} <: AbstractBehavior{T} end



"""
Abstract types for joint flows.
"""

abstract type AbstractJointFlowData <: AbstractBehaviorData end

abstract type AbstractJointFlow{T} <: AbstractBehavior{T} end

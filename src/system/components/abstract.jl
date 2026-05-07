"""
Abstract types for components, models, and behaviors.
"""

abstract type AbstractComponent{T} <: AbstractElement{T} end


"""
AbstractBehaviorData: supertype for behavior data.
Behavior data encapsulates the data required to generate behaviors.
It is directly constructed by the user call to the constructor.
"""

abstract type AbstractBehaviorData <: AbstractElement{Float64} end


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

Interface in file: jointflows/abstract.jl
"""

"""
AbstractJointFlowData: supertype for joint flow data.
Joint flow data encapsulates the data required to generate behaviors.
It is directly constructed by the user call to the constructor.
It behaves very similarly to AbstractBehaviorData.

AbstractJointFlowData interface:
  * implement buildjointflow(c::Component, cname::String, b::AbstractBehaviorData) -> return a AbstractBehavior
"""

abstract type AbstractJointFlowData <: AbstractBehaviorData end

"""
AbstractJointFlow: supertype for joint flows.
Joint flows themselves are not constructed by the user. 
The constructor is called by the component constructor instead.

AbstractJointFlow interface:
  * implement jointflowname(::AbstractJointFlow)::String -> return a String (category of joint flow name e.g. fixed, linked etc.)
  * implement name(::AbstractJointFlow)::String -> return a String (name of the current flow e.g. CO2, electricity etc.)
  * implement mustconnect(::AbstractJointFlow)::Bool -> return a Bool (true if the user must use connect! to connect the associated port, false if not)
"""

abstract type AbstractJointFlow{T} <: AbstractBehavior{T} end

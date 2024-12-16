"""
Abstract types for joint flows data and joint flows.
"""

"""
AbstractJointFlowData: supertype for joint flow data.
Joint flow data encapsulates the data required to generate behaviors.
It is directly constructed by the user call to the constructor.
It behaves very similarly to AbstractBehaviorData.
"""

# abstract type AbstractJointFlowData <: AbstractBehaviorData end


"""
AbstractJointFlow: supertype for joint flows.
Joint flows themselves are not constructed by the user. 
The constructor is called by the component constructor instead.
"""

# abstract type AbstractJointFlow{T} <: AbstractBehavior{T} end

"""
AbstractJointFlowData interface:
  * implement buildjointflow(c::Component, cname::String, b::AbstractBehaviorData) -> return a AbstractBehavior
"""

buildbehavior(c::Component, b::AbstractJointFlowData) = buildjointflow(c, b)


# joint flows don't have constraints - following method should never be called
_apply_constraints!(::Component, ::AbstractJointFlow) = error("This method should never be called")

jointflowname(::AbstractJointFlow) = error("not implemented")
name(::AbstractJointFlow) = error("not implemented")
mustconnect(::AbstractJointFlow) = error("not implemented")

# display joint flow info
function Base.show(io::IO, b::AbstractJointFlow)
  fn = name(b)
  sn = b.data.sense == :input ? "input" : "output"
  ft = jointflowname(b)
  cn = modifiername(_defaultmodifier(carrierstyle(b.data.carrier)))
  print(
      io, 
      "Joint flow \"$fn\" (sense = $sn, type = $ft) for carrier $cn"
  )
end
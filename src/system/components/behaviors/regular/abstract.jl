
"""
AbstractRegularBehaviorData interface:
  * implement buildbehavior(c::Component, cname::String, b::AbstractBehaviorData) -> return a AbstractBehavior
"""

buildbehavior(::Component, ::String, ::AbstractRegularBehavior) = error("Not implemented")


"""
AbstractRegularBehavior interface:
  * implement behaviorname(b::AbstractBehaviorModel) -> return a String
  * implement _apply_constraints!(c::Component, b::AbstractBehavior) -> apply constraints to component, return nothing
"""

behaviorname(::AbstractRegularBehavior) = error("Not implemented")
_apply_constraints!(::Component, ::AbstractRegularBehavior) = error("Not implemented")


# display behavior info
function Base.show(io::IO, b::AbstractRegularBehavior)
  print(
      io, 
      "Behavior \"$(behaviorname(b))\""
  )
end
"""
Model formalism:
  * model data (defined by the user) is a subtype of AbstractModelData
  * model (constructed from model data by component constructor) is a subtype of AbstractModel
"""

abstract type AbstractModelData end

abstract type AbstractModel{T<:VAL} <: AbstractElement{T} end

"""
AbstractModel interface:

Implemented by default, can be customized:
  * implement portstructure(m::AbstractModel) -> return port structure associated with model
  * implement sim(m::AbstractModel) => return Sim associated with model
  * implement hasport(m::AbstractModel, pname::String) => return boolean indicating whether model has port named pname

Not implemented by default:
  * implement _apply_constraints!(m::AbstractModel) => apply constraints related to the model
  * implement modelname(m::AbstractModel) => return String with model name
"""


# default implementation of portstructure
portstructure(m::AbstractModel) = m.s

# default implementation of sim
sim(m::AbstractModel) = m.data.sim

hasport(m::AbstractModel, pname::String) = hasport(m.s, pname)

hasinput(m::AbstractModel, pname::String) = hasinput(portstructure(m), pname::String)
hasoutput(m::AbstractModel, pname::String) = hasoutput(portstructure(m), pname::String)
haslevel(m::AbstractModel, pname::String) = haslevel(portstructure(m), pname::String)

getport(m::AbstractModel, pname::String) = getport(portstructure(m), pname)

# fallback function for _apply_constraints!
# used when no specific model constraint is defined
_apply_constraints!(::AbstractModel) = error("Not implemented")

modelname(::AbstractModel) = error("Not implemented")
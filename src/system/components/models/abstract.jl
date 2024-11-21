"""
Model formalism:
  * model data (defined by the user) is a subtype of AbstractModelData
  * model (constructed from model data by component constructor) is a subtype of AbstractModel
"""

abstract type AbstractModelData end

abstract type AbstractModel{T<:VAL} <: AbstractElement{T} end

"""
AbstractModel interface:
  * implement portstructure(m::AbstractModel) -> return port structure associated with model
"""


# default implementation of portstructure
portstructure(m::AbstractModel) = m.s

hasinput(m::AbstractModel, pname::String) = hasinput(portstructure(m), pname::String)
hasoutput(m::AbstractModel, pname::String) = hasoutput(portstructure(m), pname::String)
haslevel(m::AbstractModel, pname::String) = haslevel(portstructure(m), pname::String)

getport(m::AbstractModel, pname::String) = getport(portstructure(m), pname)


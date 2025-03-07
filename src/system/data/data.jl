using JuMP: VariableRef, AffExpr, GenericAffExpr
using BilevelJuMP: BilevelVariableRef, BilevelAffExpr

"""
Manipulation of numbers and affine expressions.
"""


const VAL = Union{Float64,GenericAffExpr}


_to_affexpr(e::GenericAffExpr, ::Any) = e
#_to_affexpr(n::Number) = GenericAffExpr(n)

_to_affexpr(n::Number, ::JuMP.Model) = convert(AffExpr, n)
_to_affexpr(n::Number, ::BilevelJuMP.BilevelModel) = convert(BilevelAffExpr, n)

#_to_affexpr(r::VariableRef) = __to_affexpr(r, r.model)
_to_affexpr(r::VariableRef, ::JuMP.Model) = convert(AffExpr, r)
_to_affexpr(r::BilevelVariableRef, ::BilevelJuMP.BilevelModel) = convert(BilevelAffExpr, r)

_to_affexpr(v::AbstractVector{<:GenericAffExpr}, ::Any) = v
_to_affexpr(v::AbstractVector{<:Number}, m::JuMP.AbstractModel) = _to_affexpr.(v, m)
_to_affexpr(v::AbstractVector{<:AbstractVariableRef}, m::JuMP.AbstractModel) = _to_affexpr.(v, m)


# return true if the GenericAffExpr is equivalent to a variable:
#  * no constant
#  * only one variable
#  * linear coefficient is 1.
_is_equivalent_to_variable(e::GenericAffExpr) = iszero(e.constant) && isone(length(e.terms)) && isone(first(e.terms)[2])




"""
Reserved names.
"""

# reserved names cannot be used when naming new components
const RESERVED_COMPONENT_NAMES = (
    "losses", # used when modeling node losses
    )

_is_reserved_component_name(name::String) = name in RESERVED_COMPONENT_NAMES
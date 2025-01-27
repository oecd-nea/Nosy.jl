using JuMP

"""
Manipulation of numbers and affine expressions.
"""

const VAL = Union{Float64,AffExpr}


_to_affexpr(e::AffExpr) = e
_to_affexpr(n::Number) = AffExpr(n)
_to_affexpr(r::VariableRef) = convert(AffExpr, r)

_to_affexpr(v::AbstractVector{AffExpr}) = v
_to_affexpr(v::AbstractVector{<:Number}) = _to_affexpr.(v)
_to_affexpr(v::AbstractVector{VariableRef}) = _to_affexpr.(v)


# return true if the AffExpr is equivalent to a variable:
#  * no constant
#  * only one variable
#  * linear coefficient is 1.
_is_equivalent_to_variable(e::AffExpr) = iszero(e.constant) && isone(length(e.terms)) && isone(first(e.terms)[2])




"""
Reserved names.
"""

# reserved names cannot be used when naming new components
const RESERVED_COMPONENT_NAMES = (
    "losses", # used when modeling node losses
    )

_is_reserved_component_name(name::String) = name in RESERVED_COMPONENT_NAMES
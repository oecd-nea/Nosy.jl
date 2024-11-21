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
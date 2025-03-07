"""
Tools for tests.
"""

using JuMP: GenericAffExpr

# quick evaluation of whether 2 GenericAffExpr are approximately the same
# they must have the same variables (keys)
# and values (coeffs) must be approx
function Base.isapprox(a::GenericAffExpr, b::GenericAffExpr)
    if !isapprox(a.constant, b.constant)
        return false
    end

    for (k,v) in a.terms
        if !haskey(b.terms, k)
            return false
        end
        if !isapprox(v, b.terms[k])
            return false
        end
    end

    for (k,v) in b.terms
        if !haskey(a.terms, k)
            return false
        end
    end

    return true
end
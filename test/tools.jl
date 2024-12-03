"""
Tools for tests.
"""

using JuMP: AffExpr

# quick evaluation of whether 2 AffExpr are approximately the same
# they must have the same variables (keys)
# and values (coeffs) must be approx
function Base.isapprox(a::AffExpr, b::AffExpr)
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
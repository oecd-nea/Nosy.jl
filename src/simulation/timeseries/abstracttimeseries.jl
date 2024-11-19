"""
AbstractTimeSeries are vectors with specific properties:
  * loop: the element which index follows the last element is the first element and vice versa; also include negative indexes
  * typed operation: no cross-type summation between time series of different types

AbstractTimeSeries are not user-facing objects. The user should obtain results in the form of regular vectors.
"""

abstract type AbstractTimeSeries{T} <: AbstractVector{T} end

"""
Implementation of AbstractVector interface for AbstractTimeSeries.
"""

Base.parent(h::AbstractTimeSeries) = h.data
Base.size(h::AbstractTimeSeries) = size(parent(h))
Base.iterate(h::AbstractTimeSeries) = iterate(parent(h))
Base.iterate(h::AbstractTimeSeries, state) = iterate(parent(h), state)
Base.eltype(h::AbstractTimeSeries) = eltype(parent(h))
Base.resize!(h::AbstractTimeSeries, i::Integer) = resize!(parent(h), i)
Base.in(x, h::AbstractTimeSeries) = in(x, parent(h))

# this snippet was taken from:
# https://github.com/Vexatos/CircularArrays.jl/blob/master/src/CircularArrays.jl
function Base.checkbounds(h::AbstractTimeSeries, I...)
    J = Base.to_indices(h, I)
    length(J) == 1 || length(J) >= ndims(h) || throw(BoundsError(h, I))
    nothing
end


"""
Find the corresponding index in the allowed interval of the time series.
"""
function remove_modulo(i::Int, modulo::Int)
    return mod(i-1, modulo) + 1
end
remove_modulo(u::UnitRange{Int64}, modulo::Int) = remove_modulo.(collect(u), modulo)

function _getactualindex(h::AbstractTimeSeries, i)
    if i in eachindex(h)
        return i
    else
        return remove_modulo(i,length(h))
    end
end


Base.getindex(h::AbstractTimeSeries, i) = getindex(h.data, _getactualindex(h, i))
Base.setindex!(h::AbstractTimeSeries, v, i) = setindex!(h.data, v, _getactualindex(h, i))


"""
Tools for time series.
"""

"""
    differentzerovector(T::DataType, m::Integer)
Return a vector of zeros of type T. Each element of the vector is a different object.
"""
function differentzerovector(T::DataType, m::Integer) # when initializing an AffExpr zero vector with zeros function, all elements point to the same AffExpr zero
    v = Vector{T}(undef, m)
    for t in eachindex(v)
        v[t] = zero(T)
    end
    return v
end

"""
    shift(s::AbstractTimeSeries, i::Int)
Return a view of `s` shifted forward of `i` steps.
"""
function shift(s::AbstractTimeSeries, i::Int) 
    @view s[begin+i:end+i]
end
"""
AbstractTimeSeries are vectors with specific properties:
  * loop by default: the element which index follows the last element is the first element and vice versa; also include negative indexes
  * typed operation: no cross-type summation between time series of different types

Circular time series fold out-of-range indices back into the modeled horizon.
Non-circular time series represent an open horizon: scalar and vector reads
outside the horizon return zero, writes outside the horizon are ignored, and
meshed `shift` operations keep the same length by holding boundary values.

AbstractTimeSeries are not user-facing objects. The user should obtain results in the form of regular vectors.
"""

abstract type AbstractTimeSeries{T} <: AbstractVector{T} end

# Default to the historical behavior: custom time series wrap around unless a
# concrete subtype, through its mesh, explicitly opts out.
iscircular(::AbstractTimeSeries) = true

"""
Implementation of AbstractVector interface for AbstractTimeSeries.
"""

Base.parent(h::AbstractTimeSeries) = h.data
Base.size(h::AbstractTimeSeries) = size(parent(h))
Base.iterate(h::AbstractTimeSeries) = iterate(parent(h))
Base.iterate(h::AbstractTimeSeries, state) = iterate(parent(h), state)
Base.eltype(h::AbstractTimeSeries) = eltype(parent(h))
Base.in(x, h::AbstractTimeSeries) = in(x, parent(h))

# this snippet was initially taken from:
# https://github.com/Vexatos/CircularArrays.jl/blob/master/src/CircularArrays.jl
# then modified
function Base.checkbounds(h::AbstractTimeSeries, I...)
    J = Base.to_indices(h, I)
    length(J) == 1 || length(J) >= ndims(h) || throw(BoundsError(h, I))
    _checkboundsindex(h, first(J), I)
    nothing
end


"""
Find the corresponding index in the allowed interval of the time series.
"""
function remove_modulo(i::Int, modulo::Int)
    return mod(i-1, modulo) + 1
end
remove_modulo(u::UnitRange{Int64}, modulo::Int) = remove_modulo.(collect(u), modulo)

_inbounds(h::AbstractTimeSeries, i::Integer) = firstindex(h) <= i <= lastindex(h)
_inbounds(h::AbstractTimeSeries, u::UnitRange) = isempty(u) || (firstindex(h) <= first(u) && last(u) <= lastindex(h))
_inbounds(h::AbstractTimeSeries, c::AbstractVector{<:Integer}) = all(i -> _inbounds(h, i), c)

function _checkboundsindex(h::AbstractTimeSeries, i, I)
    # Circular series accept any integer index because it can be folded back
    # into the modeled horizon. Non-circular series keep Julia's bounds checks
    # for explicit checkbounds calls.
    (iscircular(h) || _inbounds(h, i)) || throw(BoundsError(h, I))
    return nothing
end

# These helpers are used by non-circular meshed `shift`, where boundary values
# must be held to keep existing vectorized behavior constraints same-sized.
_clampindex(h::AbstractTimeSeries, i::Integer) = clamp(i, firstindex(h), lastindex(h))
_clampindex(h::AbstractTimeSeries, u::UnitRange) = [_clampindex(h, i) for i in u]
_clampindex(h::AbstractTimeSeries, c::AbstractVector{<:Integer}) = [_clampindex(h, i) for i in c]

function _getactualindex(h::AbstractTimeSeries, i)
    # Keep one canonical place for index folding. Non-circular out-of-horizon
    # reads are handled by getindex before reaching this helper because they
    # mean "outside the modeled period", not "another valid storage location".
    if _inbounds(h, i)
        return i
    elseif iscircular(h)
        return remove_modulo(i,length(h))
    else
        throw(BoundsError(h, i))
    end
end

_zero_padded_getindex(::AbstractTimeSeries{T}, ::Integer) where T = zero(T)
_zero_padded_getindex(h::AbstractTimeSeries{T}, indices) where T = [(_inbounds(h, i) ? h.data[i] : zero(T)) for i in indices]

function Base.getindex(h::AbstractTimeSeries, i::Union{Integer,UnitRange{<:Integer},AbstractVector{<:Integer}})
    # Open-boundary duration logic (e.g. unit startup/shutdown tails) may ask
    # for values just outside the horizon. Zero-padding makes those tails
    # vanish outside the modeled period instead of reappearing at the other end,
    # and keeps scalar, range, and vector reads consistent.
    if !iscircular(h) && !_inbounds(h, i)
        return _zero_padded_getindex(h, i)
    end
    return getindex(h.data, _getactualindex(h, i))
end

function Base.setindex!(h::AbstractTimeSeries, v, i)
    # Some algorithms accumulate derived effects at t±k. For non-circular time,
    # contributions outside the horizon should be discarded, not wrapped or
    # clamped onto the boundary timestep.
    (!iscircular(h) && !_inbounds(h, i)) && return h
    return setindex!(h.data, v, _getactualindex(h, i))
end


"""
Tools for time series.
"""

"""
    differentzerovector(T::DataType, m::Integer)
Return a vector of zeros of type T. Each element of the vector is a different object.
"""
function differentzerovector(T::DataType, m::Integer) # when initializing an GenericAffExpr zero vector with zeros function, all elements point to the same GenericAffExpr zero
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

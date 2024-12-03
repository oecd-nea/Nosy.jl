using OrderedCollections: LittleDict

"""
Balances on PortStructure.

sense ∈ [input, output, level]

Collapsed: summation over the time series -> return ~yearly sum.
Agggregated: summation of the times series together -> return value for all time series together

The methods below are not user-facing methods.
The time series-like return are Stepwise, not Hourly.

Specific care should be used when applying the non-collapsed, aggregated _balance method, as it allocates for a new vector of length nsteps.
A possible workflow could be to check for the existence of keys before assessing it.
"""

# return a LittleDict of name => Stepwise of the modified series
function _balance_expand(ps::PortStructure{T}, sense::Function, modifier::Function) where T
    d = LittleDict{String,Stepwise{T}}()
    for (k,v) in sense(ps)
        if !isnothing(modifier(carrier(v)))
            d[k] = modifier(v)
        end
    end
    return d
end

# perform balance on only one port
# faster than performing balance on all ports
_balance_one(ps::PortStructure, pname::String, sense::Function, modifier::Function) = modifier(sense(ps)[pname])
_balance_one(ps::PortStructure, pname::String, modifier::Function) = modifier(getport(ps, pname))
_collapse_balance_one(ps::PortStructure, pname::String, sense::Function, modifier::Function) = sum(_balance_one(ps, pname, sense, modifier))

_collapse_balance(b::AbstractDict{String,Stepwise{T}}) where T = LittleDict{String,T}(k => sum(v) for (k,v) in b)

function _aggregate_balance(b::AbstractDict{String,Stepwise{T}}, s::Sim) where T 
    if isempty(b) 
        # not returning the "differentzerovector" because it is not supposed to every be assigned a non-zero value for any step
        # a simple zero vector is returned instead
        return Stepwise(zeros(T, nsteps(s)), s.mesh)
        # return Stepwise(differentzerovector(T, nsteps(s)), s.mesh) # too many allocations
    else
        return sum(values(b))
    end
end

_aggregate_balance(b::AbstractDict{String,T}, ::Sim) where T<: VAL = sum(values(b))

# type-unstable function, added barrier functions
function _balance(ps::PortStructure{T}, sense::Function, modifier::Function, collapse::Bool, aggregate::Bool) where T
    
    # non-collapsed, non-aggregated balance
    b = _balance_expand(ps, sense, modifier)
    # collapse if requested
    if collapse
        # sum(v::Stepwise) returns the weighted sum, not the natural sum
        # i.e. sum(v::Stepwise) == sum(Hourly(v))
        d = _collapse_balance(b)
    else
        d = b
    end

    # aggregate if requested
    if aggregate
        v = _aggregate_balance(d, sim(ps))
    else
        v = d
    end

    return v
end
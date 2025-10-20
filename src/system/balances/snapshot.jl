"""
Balances for snapshots.
"""

using ArgCheck: @argcheck, ArgumentError

"""
    balance(s::Snapshot, name::String, sense::Symbol, modifier::Function; collapse::Bool=false, aggregate::Bool=false)
Return the flow balance for component or node `name` in snapshot `s` with sense `sense` and modifier `modifier`.
Optional arguments:
  * `collapse`: if `true`, the flows are summed over time, otherwise Hourly time series are returned
  * `aggregate`: if `true`, the multiple flows are summed together, otherwise one entry per flow is returned
"""
function balance(s::Snapshot, name::String, sense::Symbol, modifier::Function; collapse::Bool=false, aggregate::Bool=false)
    return __to_hourly(_balance(s, name, sense, modifier, collapse=collapse, aggregate=aggregate)) # user-facing method, return hourly version
end

function _balance(s::Snapshot, name::String, sense::Symbol, modifier::Function; collapse::Bool=false, aggregate::Bool=false)
    if hascomponent(s, name)
        c = getcomponent(s, name)
    elseif hasnode(s, name)
        c = getnode(s, name)
    else
        throw(AssertionError("The snapshot does not contain node or component with name $name"))
    end 
    return _balance(c, sense, modifier, collapse=collapse, aggregate=aggregate)
end

# # convert Stepwise to Hourly
# nothing to do for other data formats
__to_hourly(s::Stepwise) = Hourly(s)
__to_hourly(d::AbstractDict{<:Any,<:Stepwise}) = Dict(k => Hourly(v) for (k,v) in d)
__to_hourly(d) = d
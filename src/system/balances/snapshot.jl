"""
Balances for snapshots.
"""

"""
    balance(s::Snapshot, name::String, sense::Symbol, modifier::Function; collapse::Bool=false, aggregate::Bool=false, hourly::Bool=true)
Return the flow balance for component or node `name` in snapshot `s` with sense `sense` and modifier `modifier`.
Optional arguments:
  * `collapse`: if `true`, the flows are summed over time, otherwise time series are returned
  * `aggregate`: if `true`, the multiple flows are summed together, otherwise one entry per flow is returned
  * `hourly`: if `true`, the time series are returned as Hourly, otherwise Stepwise (only for `collapse=false`)
"""
function balance(s::Snapshot, name::String, sense::Symbol, modifier::Function; collapse::Bool=false, aggregate::Bool=false, hourly::Bool=true)
    if hascomponent(s, name)
        c = getcomponent(s, name)
    elseif hasnode(s, name)
        c = getnode(s, name)
    end
    
    b = balance(c, sense, modifier, collapse=collapse, aggregate=aggregate)
    
    if hourly
        return _to_hourly(b) # user-facing method, return hourly version
    else
        return b
    end
end

# convert Stepwise to Hourly
# nothing to do for other data formats
_to_hourly(s::Stepwise) = Hourly(s)
_to_hourly(d::AbstractDict{String,<:Stepwise}) = Dict(k => Hourly(v) for (k,v) in d)
_to_hourly(d) = d
"""
Balances for snapshots.
"""

using ArgCheck: @argcheck, ArgumentError

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

# return a node or component from a snapshot
# not type-stable
function getnodeorcomponent(s::Snapshot, name::String)
    if hascomponent(s, name)
        c = getcomponent(s, name)
    elseif hasnode(s, name)
        c = getnode(s, name)
    else
        throw(ArgumentError("Could not find component or node with name $name"))
    end
end

# check the integrity of the request
# do nothing if correct
function _check_args_flow(hour, day, month)
    @argcheck sum(isnothing(f) for f in (hour, day, month)) >= 2 "At maximum one of `hour`, `day`, or `month` can be set"
    @argcheck isnothing(hour) || isinteger(hour) "hour must be either nothing or an integer"
    @argcheck isnothing(day) || day in 1:365 "day must be either nothing or an integer between 1 and 365"
    @argcheck isnothing(month) || month in 1:12 "day must be either nothing or an integer between 1 and 365"
end

# return the sum of a Hourly for a given month
_getsum_month(h::Hourly, month::Int) = sum(h[i] for i in eachindex(h) if _month(i) == month)

# return the sum of a Hourly for a given day
_getsum_day(h::Hourly, day::Int) = sum(h[i] for i in eachindex(h) if _day(i) == day)

"""
    flow(s::Snapshot, name::String, sense::Symbol, modifier::Function, hour::Int)
Return the flow of Node or Component with name `name`, in sense `sense`, with modifier `modifier`.
Optional arguments:
  * `hour` ∈ 1:8760: return the flow at a given `hour`
  * `day` ∈ 1:365: return the integral of the flow at a given `day`
  * `month` ∈ 1:12: return the integral of the flow at a given `month`
If no optional argument is given, the integral of the flow for the full year is returned.
"""
function flow(s::Snapshot, name::String, sense::Symbol, modifier::Function; hour=nothing, day=nothing, month=nothing)
    _check_args_flow(hour, day, month)
    c = getnodeorcomponent(s, name)
    if !isnothing(hour)
        return flow(c, sense, modifier, hour)
    elseif !isnothing(day)
        b = balance(c, sense, modifier, collapse=false, aggregate=true)
        return _getsum_day(_to_hourly(b), day)
    elseif !isnothing(month)
        b = balance(c, sense, modifier, collapse=false, aggregate=true)
        return _getsum_month(_to_hourly(b), month)
    else
        return balance(c, sense, modifier, collapse=true, aggregate=true)
    end
end

"""
    flow(s::Snapshot, name::String, pname::String, sense::Symbol, modifier::Function, hour::Int)
Return the flow of port `pname` of Node or Component with name `name`, in sense `sense`, with modifier `modifier`.
Optional arguments:
  * `hour` ∈ 1:8760: return the flow at a given `hour`
  * `day` ∈ 1:365: return the integral of the flow at a given `day`
  * `month` ∈ 1:12: return the integral of the flow at a given `month`
If no optional argument is given, the integral of the flow for the full year is returned.
"""
function flow(s::Snapshot, name::String, pname::String, sense::Symbol, modifier::Function; hour=nothing, day=nothing, month=nothing)
    _check_args_flow(hour, day, month)
    c = getnodeorcomponent(s, name)
    if !isnothing(hour)
        return flow(c, pname, sense, modifier, hour)
    elseif !isnothing(day)
        b = _balance(c, pname, sense, modifier, collapse=false)
        return _getsum_day(_to_hourly(b), day)
    elseif !isnothing(month)
        b = _balance(c, pname, sense, modifier, collapse=false)
        return _getsum_month(_to_hourly(b), month)
    else
        return _balance(c, pname, sense, modifier, collapse=true)
    end
end
"""
Component balance.

Direct application of the balance on the port structure of the component.
"""

"""
    balance(c::Component, sense::Symbol, modifier::Function; collapse::Bool=true, aggregate::Bool=true)

Return the flow balance for component `c`.

Parameters:
  * `c`: Component
  * `sense`: `:input`, `:output`, or `:level`
  * `modifier`: modifier function e.g. `energy`, `mass`, `co2`
  * `collapse`: if `true`, the flows are summed over time; otherwise the `Hourly` series are returned. Must be `false` when `sense` is `:level`.
  * `aggregate`: if `true`, the multiple flows are summed together, otherwise one entry per flow is returned
"""
function balance(c::Component, sense::Symbol, modifier::Function; collapse::Bool=true, aggregate::Bool=true)
    @argcheck sense in (:input, :output, :level) "sense must be either :input or :output or :level"
    return __to_hourly(_balance(c, sense, modifier, collapse=collapse, aggregate=aggregate))
end

function _balance(c::Component, sense::Symbol, modifier::Function; collapse::Bool=true, aggregate::Bool=true)
    if sense == :input
        b = _balance(c.s, _input, modifier, collapse, aggregate)
    elseif sense == :output
        b = _balance(c.s, _output, modifier, collapse, aggregate)
    elseif sense == :level
        if collapse
            throw(ArgumentError("collapse must be false when sense is :level"))
        end
        b = _balance(c.s, _level, modifier, collapse, aggregate)
    end
    aggregate && return b
    return Dict(k.pname => v for (k,v) in b) # all flows have different port names, no ambiguity here
end

# balance applied to only one port of the component
# this function should not be exported, it is used for behaviors e.g. variable cost
# this is almost the same method as for nodes
function _balance(c::Component, pname::String, sense::Symbol, modifier::Function; collapse::Bool=true)
    @argcheck sense in (:input, :output) "sense must be either :input or :output"
    if sense == :input
        @argcheck hasinput(c, pname) "Component $(name(c)) does not have input $pname"
        if collapse
            return _collapse_balance_one(c.s, pname, name(c), _input, modifier)
        else
            return _balance_one(c.s, pname, name(c), _input, modifier)
        end
    else # if sense == :output
        @argcheck hasoutput(c, pname) "Component $(name(c)) does not have output $pname"
        if collapse
            return _collapse_balance_one(c.s, pname, name(c), _output, modifier)
        else
            return _balance_one(c.s, pname, name(c), _output, modifier)
        end
    end
end



# return the flow of a port at a given timestep
_flow(c::Component, pname::String, modifier::Function, step::Int) = _flow(c.s, pname, name(c), modifier, step)
_flow(c::Component, pname::String, sense::Symbol, modifier::Function, step::Int) = _flow(c.s, pname, name(c), sense, modifier, step)

"""
    flow(c::Component, pname::String, modifier::Function, hour::Int)

Return the value of the flow of port named `pname` of component `c` at hour `hour` modified by `modifier`.
"""
function flow(c::Component, pname::String, modifier::Function, hour::Int)
    return _flow(c, pname, modifier, step(sim(c).mesh, hour))
end

"""
    flow(c::Component, pname::String, sense::Symbol, modifier::Function, hour::Int)

Return the value of the flow of port named `pname` in sense `sense` of component `c` at hour `hour`, modified by `modifier`.
"""
function flow(c::Component, pname::String, sense::Symbol, modifier::Function, hour::Int)
    return _flow(c, pname, sense, modifier, step(sim(c).mesh, hour))
end

# return the sum of all flows for a full sense at a given timestep
# do not throw error if no compatible ports are found - return zero instead
function _flow(c::Component{T}, sense::Symbol, modifier::Function, step::Int) where T
    local val = zero(T)
    for (_, p) in _getportsense(c.s, sense)
        # check port and modifier compatibility
        # if not do not evaluate flow for p
        if hasmodifier(p.carrier, modifier)
            val = addto!(val, _flow(p, modifier, step))
        end
    end
    return val
end

"""
    flow(c::Component, sense::Symbol, modifier::Function, hour::Int)

Return the sum of the flows in sense `sense` of component `c` at hour `hour`, modified by `modifier`.
Return zero if no port in that sense is compatible with `modifier`.
"""
function flow(c::Component, sense::Symbol, modifier::Function, hour::Int)
    return _flow(c, sense, modifier, step(sim(c).mesh, hour))
end

"""
    table(c::Component, modifier::Function; collapse::Bool=false)

Perform a balance at all the ports of the component, following a given modifier.
If `collapse` is `true`, return an `OrderedDict` of `portname => yearly balance`.
If `collapse` is `false`, return a `DataFrame` of `Hourly` time series per port.
"""
function table(c::Component{T}, modifier::Function; collapse::Bool=false) where T
    b = OrderedDict(
        :input => balance(c, :input, modifier, aggregate=false, collapse=collapse),
        :output => balance(c, :output, modifier, aggregate=false, collapse=collapse),
    )
    if !collapse
        b[:level] = balance(c, :level, modifier, aggregate=false, collapse=false)
    end
    
    if collapse
        res = OrderedDict{String,T}()
        for (_,v) in b
            for (k2, v2) in v
                res[k2] = v2
            end
        end
    else
        # merging the sub dicts together, all ports have different name by invariance
        d = OrderedDict{String,Vector{T}}()
        for (_,v) in b
            for (k2,v2) in v
                d[k2] = v2.data
            end
        end
        res = DataFrame(d)
    end

    return res
end
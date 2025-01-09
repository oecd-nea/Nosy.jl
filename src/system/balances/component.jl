"""
Component balance.

Direct application of the balance on the port structure of the component.
"""


"""
    balance(c::Component, sense::Symbol, modifier::Function; collapse::Bool=true, aggregate::Bool=true)
Return the flow balance for component `c`.
Parameters:
  * `c`: Component
  * `sense`: `input` or `:output`
  * `modifier`: modifier function e.g. `energy`, `mass`, `co2`
  * `collapse`: if `true`, the flows are summed over time, otherwise the Stepwise series are returned
  * `aggregate`: if `true`, the multiple flows are summed together, otherwise one entry per flow is returned
"""
function balance(c::Component, sense::Symbol, modifier::Function; collapse::Bool=true, aggregate::Bool=true)
    @argcheck sense in (:input, :output) "sense must be either :input or :output"
    if sense == :input
        return _balance(c.s, _input, modifier, collapse, aggregate)
    else # if sense == :output
        return _balance(c.s, _output, modifier, collapse, aggregate)
    end
end

# balance applied to only one port of the component
# this function should not be exported, it is used for behaviors e.g. variable cost
# this is almost the same method as for nodes
function _balance(c::Component, pname::String, sense::Symbol, modifier::Function; collapse::Bool=true)
    @argcheck sense in (:input, :output) "sense must be either :input or :output"
    if sense == :input
        @argcheck hasinput(c.s, pname) "Component $(name(c)) does not have input $pname"
        if collapse
            return _collapse_balance_one(c.s, pname, _input, modifier)
        else
            return _balance_one(c.s, pname, _input, modifier)
        end
    else # if sense == :output
        @argcheck hasoutput(c.s, pname) "Component $(name(c)) does not have output $pname"
        if collapse
            return _collapse_balance_one(c.s, pname, _output, modifier)
        else
            return _balance_one(c.s, pname, _output, modifier)
        end
    end
end



# return the flow of a port at a given timestep
_flow(c::Component, pname::String, modifier::Function, step::Int) = _flow(c.s, pname, modifier, step)
_flow(c::Component, pname::String, sense::Symbol, modifier::Function, step::Int) = _flow(c.s, pname, sense, modifier, step)

"""
    flow(c::Component, pname::String, modifier::Function, hour::Int)
Return the value of the flow of port named `pname` of component `c` at hour `hour` modified by `modifier`.
"""
function flow(c::Component, pname::String, modifier::Function, hour::Int)
    return _flow(c, pname, modifier, step(sim(c).mesh, hour))
end

"""
    flow(c::Component, pname::String, sense::Symbol, modifier::Function, hour::Int)
Return the value of the flow of port named `pname` of component `c` at hour `hour` modified by `modifier`.
"""
function flow(c::Component, pname::String, sense::Symbol, modifier::Function, hour::Int)
    return _flow(c, pname, sense, modifier, step(sim(c).mesh, hour))
end

# return the sum of all flows for a full sense at a given timestep
# do not throw error if no compatible ports are found - return zero instead
function _flow(c::Component{T}, sense::Symbol, modifier::Function, step::Int) where T
    local val = zero(T)
    for (_, p) in getportsense(c.s, sense)
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
Return the value of the the sum of the flows in sense `sense` of component `c` at hour `hour` modified by `modifier`.
Return zero if the port is not compatible with `modifier`.
"""
function flow(c::Component, sense::Symbol, modifier::Function, hour::Int)
    return _flow(c, sense, modifier, step(sim(c).mesh, hour))
end
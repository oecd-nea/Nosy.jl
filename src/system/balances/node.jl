"""
Node balance.

Direct application of the balance on the port structure of the node.

`balance`` method is user-facing and should never return Stepwise (or Dict of Stepwise etc.).
"""


"""
    balance(n::Node, sense::Symbol, modifier::Function; collapse::Bool=true, aggregate::Bool=true)
Return the flow balance for node `n`.
Parameters:
  * `n`: Node
  * `sense`: `:input` or `:output`
  * `modifier`: modifier function e.g. `energy`, `mass`, `co2`
  * `collapse`: if `true`, the flows are summed over time, otherwise the Hourly series are returned
  * `aggregate`: if `true`, the multiple flows are summed together, otherwise one entry per flow is returned
"""
function balance(n::Node, sense::Symbol, modifier::Function; collapse::Bool=true, aggregate::Bool=true)
    @argcheck sense in (:input, :output) "sense must be either :input or :output"
    return __to_hourly(_balance(n, sense, modifier; collapse=collapse, aggregate=aggregate))
end

function _balance(n::Node, sense::Symbol, modifier::Function; collapse::Bool=true, aggregate::Bool=true)
    if sense == :input
        return _balance(n.s, _input, modifier, collapse, aggregate)
    else # if sense == :output
        return _balance(n.s, _output, modifier, collapse, aggregate)
    end
end

# balance applied to only one port of the node
# this function should not be exported, it is used for behaviors e.g. variable cost
# this is almost the same method as for components - with added argument (cname + pname, otherwise port is ambiguous)
function _balance(n::Node, cname::String, pname::String, sense::Symbol, modifier::Function; collapse::Bool=true)
    @argcheck sense in (:input, :output) "sense must be either :input or :output"
    if sense == :input
        @argcheck hasinput(n.s, pname) "Node $(name(n)) does not have input $pname"
        if collapse
            return _collapse_balance_one(n.s, pname, _input, modifier)
        else
            return _balance_one(n.s, pname, _input, modifier)
        end
    else # if sense == :output
        @argcheck hasoutput(n.s, pname) "Node $(name(n)) does not have output $pname"
        if collapse
            return _collapse_balance_one(n.s, pname, _output, modifier)
        else
            return _balance_one(n.s, pname, _output, modifier)
        end
    end
end

# return the flow of a node port at a given timestep
_flow(n::Node, pname::String, modifier::Function, step::Int) = _flow(n.s, pname, name(n), modifier, step)
_flow(n::Node, pname::String, sense::Symbol, modifier::Function, step::Int) = _flow(n.s, pname, name(n), sense, modifier, step)


"""
    flow(n::Node, pname::String, modifier::Function, hour::Int)
Return the value of the flow of port named `pname` of node `n` at hour `hour` modified by `modifier`.
"""
function flow(n::Node, pname::String, modifier::Function, hour::Int)
    return _flow(n, pname, modifier, step(sim(n).mesh, hour))
end

"""
    flow(n::Node, pname::String, sense::Symbol, modifier::Function, hour::Int)
Return the value of the flow of port named `pname` in sense `sense` of node `n` at hour `hour` modified by `modifier`.
"""
function flow(n::Node, pname::String, sense::Symbol, modifier::Function, hour::Int)
    return _flow(n, pname, sense::Symbol, modifier, step(sim(n).mesh, hour))
end

# No carrier check for each port because all node ports have the same carrier
# do not throw error if carrier is not compatible - return zero instead
function _flow(n::Node{T}, sense::Symbol, modifier::Function, step::Int) where T
    local val = zero(T)
    if hasmodifier(n.carrier, modifier)
        for (_, p) in _getportsense(n.s, sense)
            val = addto!(val, _flow(p, modifier, step))
        end
    end
    return val
end

"""
    flow(n::Node, sense::Symbol, modifier::Function, hour::Int)
Return the value of the the sum of the flows in sense `sense` of node `n` at hour `hour` modified by `modifier`.
Return zero if the node's carrier is not compatible with `modifier`.
"""
function flow(n::Node, sense::Symbol, modifier::Function, hour::Int)
    return _flow(n, sense, modifier, step(sim(n).mesh, hour))
end
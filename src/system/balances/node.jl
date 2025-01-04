"""
Node balance.

Direct application of the balance on the port structure of the node.
"""


"""
    balance(n::Node, sense::Symbol, modifier::Function; collapse::Bool=true, aggregate::Bool=true)
Return the flow balance for node `n`.
Parameters:
  * `n`: Node
  * `sense`: `:input` or `:output`
  * `modifier`: modifier function e.g. `energy`, `mass`, `co2`
  * `collapse`: if `true`, the flows are summed over time, otherwise the Stepwise series are returned
  * `aggregate`: if `true`, the multiple flows are summed together, otherwise one entry per flow is returned
"""
function balance(n::Node, sense::Symbol, modifier::Function; collapse::Bool=true, aggregate::Bool=true)
    @argcheck sense in (:input, :output) "sense must be either :input or :output"
    if sense == :input
        return _balance(n.s, _input, modifier, collapse, aggregate)
    else # if sense == :output
        return _balance(n.s, _output, modifier, collapse, aggregate)
    end
end

# return the flow of a node port at a given timestep
_flow(n::Node, pname::String, modifier::Function, step::Int) = _flow(n.s, pname, modifier, step)

"""
    flow(n::Node, pname::String, modifier::Function, hour::Int)
Return the value of the flow of port named `pname` of node `n` at hour `hour` modified by `modifier`.
"""
function flow(n::Node, pname::String, modifier::Function, hour::Int)
    return _flow(n, pname, modifier, step(sim(n).mesh, hour))
end



# No carrier check for each port because all node ports have the same carrier
# do not throw error if carrier is not compatible - return zero instead
function _flow(n::Node{T}, sense::Symbol, modifier::Function, step::Int) where T
    local val = zero(T)
    if hasmodifier(n.carrier, modifier)
        for (_, p) in getportsense(n.s, sense)
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
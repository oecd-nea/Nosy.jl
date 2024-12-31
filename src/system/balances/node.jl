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
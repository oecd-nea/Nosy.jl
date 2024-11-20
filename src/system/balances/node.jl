"""
Node balance.

Direct application of the balance on the port structure of the node.
"""


"""
    _balance(n::Node, sense::Function, modifier::Function; collapse::Bool=true, aggregate::Bool=true)
Return the flow balance for node `n`.
Parameters:
  * `n`: Node
  * `sense`: sense function e.g. `input`, `output`
  * `modifier`: modifier function e.g. `energy`, `mass`, `co2`
  * `collapse`: if `true`, the flows are summed over time, otherwise the Stepwise series are returned
  * `aggregate`: if `true`, the multiple flows are summed together, otherwise one entry per flow is returned
"""
# the following method is not user-facing as it potentially returns Stepwise data, not Hourly data
function _balance(n::Node, sense::Function, modifier::Function; collapse::Bool=true, aggregate::Bool=true)
    return _balance(n.s, sense, modifier, collapse, aggregate)
end

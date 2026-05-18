"""
Node balance.

Direct application of the balance on the port structure of the node.

The `balance` method is user-facing and should never return `Stepwise`
objects, including containers of `Stepwise` objects.
"""


"""
    balance(n::Node, sense::Symbol, modifier::Function; collapse::Bool=true, aggregate::Bool=true)

Return the flow balance for node `n`.

Parameters:
  * `n`: Node
  * `sense`: `:input` or `:output`
  * `modifier`: modifier function e.g. `energy`, `mass`, `co2`
  * `collapse`: if `true`, the flows are summed over time; otherwise the `Hourly` series are returned
  * `aggregate`: if `true`, the flows from multiple components are summed together, otherwise one entry per component is returned
"""
function balance(n::Node, sense::Symbol, modifier::Function; collapse::Bool=true, aggregate::Bool=true)
    @argcheck sense in (:input, :output) "sense must be either :input or :output"
    return __to_hourly(_balance(n, sense, modifier; collapse=collapse, aggregate=aggregate))
end

function _balance(n::Node, sense::Symbol, modifier::Function; collapse::Bool=true, aggregate::Bool=true)
    if sense == :input
        b = _balance(n.s, _input, modifier, collapse, aggregate)
    else # if sense == :output
        b = _balance(n.s, _output, modifier, collapse, aggregate)
    end
    aggregate && return b

    # multiple PortRef in keys of b may be associated with same cname - aggregate by cname
    return __mergebalancebycname(b)
end

function __mergebalancebycname(b::AbstractDict{PortRef,<:Any})
    merged = __containertype(b){String,valtype(b)}() # same type of Dict (LittleDict, Dict etc.), with String keys and same type of values
    for (k,v) in b
        if haskey(merged, k.cname)
            merged[k.cname] = addto!.(merged[k.cname], v)
        else
            merged[k.cname] = v
        end
    end
    return merged
end
"""
Component balance.

Direct application of the balance on the port structure of the component.
"""


"""
    _balance(c::Component, sense::Symbol, modifier::Function; collapse::Bool=true, aggregate::Bool=true)
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
        return _balance(c.s, input, modifier, collapse, aggregate)
    else # if sense == :output
        return _balance(c.s, output, modifier, collapse, aggregate)
    end
end

# balance applied to only one port of the component
# this function should not be exported, it is used for behaviors e.g. variable cost
function _balance(c::Component, pname::String, sense::Symbol, modifier::Function; collapse::Bool=true)
    @argcheck sense in (:input, :output) "sense must be either :input or :output"
    if sense == :input
        @argcheck hasinput(c.s, pname) "Component $(name(c)) does not have input $pname"
        if collapse
            return _collapse_balance_one(c.s, pname, input, modifier)
        else
            return _balance_one(c.s, pname, input, modifier)
        end
    else # if sense == :output
        @argcheck hasoutput(c.s, pname) "Component $(name(c)) does not have output $pname"
        if collapse
            return _collapse_balance_one(c.s, pname, output, modifier)
        else
            return _balance_one(c.s, pname, output, modifier)
        end
    end
end
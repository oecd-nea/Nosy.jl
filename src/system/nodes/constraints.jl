using JuMP: @constraint

"""
Node constraints.
"""

# apply the node constraints, depending on the node rule
function apply_constraints!(n::Node)
    _in = balance(n, :input, defaultmodifier, collapse=false, aggregate=true)
    _out = balance(n, :output, defaultmodifier, collapse=false, aggregate=true)
    if iscurtailed(n)
        _curtailednodeconstraint!(n, _in, _out)
    else
        _defaultnodeconstraint!(n, _in, _out)
    end
end

function _defaultnodeconstraint!(n::Node, _in::Stepwise, _out::Stepwise)
    @constraint(sim(n).model, _in .== _out)
end

function _curtailednodeconstraint!(n::Node, _in::Stepwise, _out::Stepwise)
    @constraint(sim(n).model, _in .>= _out)
end
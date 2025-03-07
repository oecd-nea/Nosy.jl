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
    c = @constraint(lowermodel(sim(n)), _in.data .== _out.data)
    _saveconstraint!(n, c)
end

function _curtailednodeconstraint!(n::Node, _in::Stepwise, _out::Stepwise)
    c = @constraint(lowermodel(sim(n)), _in.data .>= _out.data)
    _saveconstraint!(n, c)
end

# save node constraints to dualprice property
# not done by default as the set of constraints may be memory-intensive (e.g. ~100 MB)
function _saveconstraint!(n::Node, c)
    if n.evalprice
        n.dualprice.val = c
    end
end
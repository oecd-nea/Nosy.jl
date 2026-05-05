using JuMP: @constraint

"""
Node constraints.
"""

# apply the node constraints, depending on the node rule
function apply_constraints!(n::Node)
    _in = _balance(n, :input, defaultmodifier, collapse=false, aggregate=true)
    _out = _balance(n, :output, defaultmodifier, collapse=false, aggregate=true)
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

    # following check avoids adding node constraint if th node has no output
    # however some solvers perform bounds propagation in presolve making this step useless

    if all(iszero.(_out))
        # if a curtailed node has no output, then the input is not constrained
        # this requires the flows to be positive or zero - which is supposed to be true in this model
        nothing
    else
        c = @constraint(lowermodel(sim(n)), _in.data .>= _out.data)
        _saveconstraint!(n, c)
    end
end

# save node constraints to dualprice property
# not done by default as the set of constraints may be memory-intensive (e.g. ~100 MB)
function _saveconstraint!(n::Node, c)
    if n.evalprice
        n.dualprice.constraints = c
    end
end

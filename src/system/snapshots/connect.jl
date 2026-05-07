"""
Methods for connecting components and nodes to snapshots.

For connection methods, the convention for sense is taking the component's sense.
"""

"""
    connect!(s::Snapshot, c::Component, n::Node, pname::String)

Connect port named `pname` of component `c` to node `n` on snapshot `s`.
"""
function connect!(s::Snapshot, c::Component, n::Node, pname::String)
    sense = portsense(portstructure(c), PortRef(name(c), pname))
    _connect!(s, c, n, sense, pname)
end

"""
    connect!(s::Snapshot, c::Component, n::Node)

Connect all compatible ports of component `c` to node `n` on snapshot `s`. 
"""
function connect!(s::Snapshot, c::Component, n::Node)
    local _connected = false
    for p in values(_input(portstructure(c)))
        if carrier(p) == carrier(n)
            _connect!(s, c, n, :input, p)
            _connected = true
        end
    end
    for p in values(_output(portstructure(c)))
        if carrier(p) == carrier(n)
            _connect!(s, c, n, :output, p)
            _connected = true
        end
    end
    if !_connected 
        throw(AssertionError("Could not connect component $(name(c)) to node $(name(n))"))
    end
end


# slow version when port handle is not available
function _connect!(s::Snapshot, c::Component, n::Node, sense::Symbol, pname::String)
    # check the snapshot is not finalized
     if is_finalized(s) 
        throw(AssertionError("Cannot connect to snapshot: the snapshot is already finalized."))
     end

    _connect!(c, n, sense, pname)
    _populatesnapshot!(s, c, n)
end

# fast version when port handle is available
function _connect!(s::Snapshot, c::Component, n::Node, sense::Symbol, p::Port)
    # check the snapshot is not finalized
    if is_finalized(s) 
        throw(AssertionError("Cannot connect to snapshot: the snapshot is already finalized."))
    end

    pname = getpname(portstructure(c), p, sense)
    _connect!(n, sense, p, name(c), pname)
    _populatesnapshot!(s, c, n)
end


# connect component to node, sense is known, general case
function _connect!(c::Component{T}, n::Node{T}, sense::Symbol, pname::String) where T
    _connect!(n, sense, getport(c, pname, sense), name(c), pname)
end

# cannot connect GenericAffExpr component to Number node and vice versa
function _connect!(c::Component{T1}, n::Node{T2}, ::Symbol, ::String) where {T1,T2}
    throw(AssertionError("Cannot connect $(name(c)) with $(name(n)): value types don't match"))    
end

function _connect!(n::Node, sense::Symbol, p::Port, cname::String, pname::String)
    if !is_used(p)
        # check carrier is the same
        if carrier(p) != carrier(n) 
            throw(AssertionError("Carriers of component and node must be the same"))
        end

        # add component port to node
        if sense == :input
            _connectinput!(n, p, cname, pname)
        elseif sense == :output
            _connectoutput!(n, p, cname, pname)
        else
            throw(ArgumentError("Sense must be :input or :output"))
        end
        set_used!(p)
    end
end

"""
Senses are opposite for the component and the node.
What goes out of a component goes into a node and vice versa.
"""

_connectinput!(n::Node, p::Port, cname::String, pname::String) = addoutput!(portstructure(n), pname, cname, p)

_connectoutput!(n::Node, p::Port, cname::String, pname::String) = addinput!(portstructure(n), pname, cname, p)

# return true (and empty string) if all the components of the snapshot are fully connected
# return a tuple of (false, not_connected_component_name) otherwise
# NB components not connected at all to the snapshot are not tested
function isfullyconnected(s::Snapshot)
    for (k,v) in components(s)
        if !isfullyconnected(v)
            return (false,k)
        end
    end
    return (true,"")
end

# throw an error indicating the name of unconnected component if the snapshot is not fully connected
# return true otherwise
function assertconnected(s::Snapshot)
    (b,cname) = isfullyconnected(s)
    if !b
        throw(AssertionError("Component $cname is not fully connected"))
    end
    return true
end
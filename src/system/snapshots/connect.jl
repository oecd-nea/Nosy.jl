"""
Methods for connecting components and nodes to snapshots.

For connection methods, the convention for sense if taking the component's sense.
"""

# sense == :input or :output
# pname: port name
function _connect!(c::Component{T}, n::Node{T}, sense::Symbol, p::Port) where T<:VAL    
    # check component port is not used
    # @assert !is_used(p) "Port is already used"

    if !is_used(p)
        # check carrier is the same
        @assert carrier(p) == carrier(n) "Carriers of component and node must be the same"

        # add component port to node
        if sense == :input
            _connectinput!(n, p, name(c))
        elseif sense == :output
            _connectoutput!(n, p, name(c))
        else
            throw(ArgumentError("Sense must be :input or :output"))
        end
        set_used!(p)
    end
end

# cannot connect AffExpr component to Number node and vice versa
function _connect!(c::Component{T1}, n::Node{T2}, ::Symbol, ::Port) where {T1,T2}
    throw(AssertionError("Cannot connect $(name(c)) with $(name(n)): value types don't match"))    
end

function _connect!(c::Component, n::Node, sense::Symbol, pname::String)  
    _connect!(c, n, sense, getport(c, pname, sense))    
end


"""
Senses are opposite for the component and the node.
What goes out of a component goes into a node and vice versa.
"""

_connectinput!(n::Node, p::Port, cname::String) = addoutput!(portstructure(n), cname, p)

_connectoutput!(n::Node, p::Port, cname::String) = addinput!(portstructure(n), cname, p)

# fill the component and node fields of a snapshot with c and n being connected
function _populatesnapshot!(s::Snapshot, c::Component, n::Node)
    addcomponent!(s, c)
    addnode!(s, n)
end

# slow version when port handle is not available
function _connect!(s::Snapshot, c::Component, n::Node, sense::Symbol, pname::String)
    # check the snapshot is not finalized
    @assert !is_finalized(s) "Cannot connect to snapshot: the snapshot is already finalized."

    _connect!(c, n, sense, pname)
    _populatesnapshot!(s, c, n)
end

# fast version when port handle is available
function _connect!(s::Snapshot, c::Component, n::Node, sense::Symbol, p::Port)
    # check the snapshot is not finalized
    @assert !is_finalized(s) "Cannot connect to snapshot: the snapshot is already finalized."

    _connect!(c, n, sense, p)
    _populatesnapshot!(s, c, n)
end

"""
    connect!(s::Snapshot, c::Component, n::Node, pname::String)
Connect port named `pname` of component `c` to node `n` on snapshot `s`. 
"""
function connect!(s::Snapshot, c::Component, n::Node, pname::String)
    sense = portsense(portstructure(c), pname)
    _connect!(s, c, n, sense, pname)
end

"""
    connect!(s::Snapshot, c::Component, n::Node)
Connect all compatible ports of component `c` to node `n` on snapshot `s`. 
"""
function connect!(s::Snapshot, c::Component, n::Node)
    local _connected = false
    for p in values(input(portstructure(c)))
        if carrier(p) == carrier(n)
            _connect!(s, c, n, :input, p)
            _connected = true
        end
    end
    for p in values(output(portstructure(c)))
        if carrier(p) == carrier(n)
            _connect!(s, c, n, :output, p)
            _connected = true
        end
    end
    @assert _connected "Could not connect component $(name(c)) to node $(name(n))"
end

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
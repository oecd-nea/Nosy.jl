"""
A snapshot contains nodes and components.
"""

using Base: RefValue
using OrderedCollections: LittleDict

struct Snapshot{T} <: AbstractElement{T}
    sim::Sim
    components::Dict{String,Component{T}}
    nodes::Dict{String,Node{T}}
    options::Dict
    finalized::RefValue{Bool}
end

defaultsnapshotoptions() = Dict()

function Snapshot(sim::Sim, options::Dict=defaultsnapshotoptions())
    Snapshot(
        sim,
        Dict{String,Component{exptype(sim)}}(),
        Dict{String,Node{exptype(sim)}}(),
        options,
        RefValue(false)
    )
end

sim(s::Snapshot) = s.sim
components(s::Snapshot) = s.components
nodes(s::Snapshot) = s.nodes

hascomponent(s::Snapshot, cname::String) = haskey(components(s), cname)
getcomponent(s::Snapshot, cname::String) = components(s)[cname]

_getwithtags(s::Snapshot, f::Function, withtags::Vector{Symbol}, withouttags::Vector{Symbol}) = sort(LittleDict([(k,v) for (k,v) in f(s) if (all(hastag(v, tag) for tag in withtags) && !any(hastag(v, tag) for tag in withouttags))]))

getcomponents(s::Snapshot, withtags::Vector{Symbol}, withouttags::Vector{Symbol}) = _getwithtags(s, components, withtags, withouttags)

"""
    getcomponents(s::Snapshot, nodename::String, tags...)
Return a Dict of components with tags `tags` connected to Node named `nodename` in Snapshot `s`.
"""
function getcomponents(s::Snapshot, nodename::String, withtags::Vector{Symbol}, withouttags::Vector{Symbol}=Symbol[])
    d0 = getcomponents(s, withtags, withouttags)
    n = getnode(s, nodename)
    d = LittleDict{String,AbstractComponent}()
    for (k,v) in d0
        if !haskey(d, k) && (haskey(_input(n), k) || haskey(_output(n), k))
            d[k] = v
        end
    end
    return d
end


getnodes(s::Snapshot, withtags::Vector{Symbol}, withouttags::Vector{Symbol}=Symbol[]) = _getwithtags(s, nodes, withtags, withouttags)

hasnode(s::Snapshot, nname::String) = haskey(nodes(s), nname)
getnode(s::Snapshot, nname::String) = nodes(s)[nname]

is_finalized(s::Snapshot) = s.finalized[]
set_finalized!(s::Snapshot) = setindex!(s.finalized, true)

# add a node entry to the dict of nodes of a snapshot
# adding a node already present does nothing
function addnode!(s::Snapshot, n::Node)
    if hasnode(s, name(n))
        if getnode(s, name(n)) == n
            nothing # node is already added
        else
            throw(AssertionError("Snapshot already has a node named $(name(n))."))
        end
    else
        if hascomponent(s, name(n))
            throw(AssertionError("Snapshot already has a component named $(name(n)). Can't add a node with the same name."))
        else
            s.nodes[name(n)] = n
        end
    end
    return nothing
end

# add a component entry to the dict of components of a snapshot
# adding a component already present does nothing
function addcomponent!(s::Snapshot, c::Component)
    if hascomponent(s, name(c))
        if getcomponent(s, name(c)) == c
            nothing # component is already added
        else
            throw(AssertionError("Snapshot already has a different component named $(name(c))."))
        end
    else
        if hasnode(s, name(c))
            throw(AssertionError("Snapshot already has a node named $(name(c)). Can't add a component with the same name."))
        else
            s.components[name(c)] = c
        end
    end
    return nothing
end

# add loss output to nodes with losses
function add_nodelosses!(s::Snapshot)
    for (_,n) in nodes(s)
        addlosses!(n)
    end
end

# apply remaining constraints associated with a snapshot
function apply_constraints!(s::Snapshot)
    # component constraints are already applied when constructing the components
    # node constraints are applied here
    for (_, n) in nodes(s)
        apply_constraints!(n)
    end
end

# fill the component and node fields of a snapshot with c and n being connected
function _populatesnapshot!(s::Snapshot, c::Component, n::Node)
    addcomponent!(s, c)
    addnode!(s, n)
end

# display snapshot info
function Base.show(io::IO, s::Snapshot)
    nc = length(components(s))
    nn = length(nodes(s))
    print(
        io, 
        "Snapshot with $nc component(s) and $nn node(s)"
    )
end
"""
A snapshot contains nodes and components.
"""

using Base: RefValue

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
        Dict{String,Component{AffExpr}}(),
        Dict{String,Node{AffExpr}}(),
        options,
        RefValue(false)
    )
end

sim(s::Snapshot) = s.sim
components(s::Snapshot) = s.components
nodes(s::Snapshot) = s.nodes

hascomponent(s::Snapshot, cname::String) = haskey(components(s), cname)
getcomponent(s::Snapshot, cname::String) = components(s)[cname]

hasnode(s::Snapshot, nname::String) = haskey(nodes(s), nname)
getnode(s::Snapshot, nname::String) = nodes(s)[nname]

is_finalized(s::Snapshot) = s.finalized[]
set_finalized!(s::Snapshot) = setindex!(s.finalized, true)

# add a node entry to the dict of nodes of a snapshot
# if the key is already present, check that the node is the same
function addnode!(s::Snapshot, n::Node)
    if haskey(s.nodes, name(n))
        @assert s.nodes[name(n)] == n "Snapshot is connected to 2 different nodes sharing the name $(name(n))"
    else
        s.nodes[name(n)] = n
    end
end

# add a component entry to the dict of components of a snapshot
# if the key is already present, check that the component is the same
function addcomponent!(s::Snapshot, c::Component)
    if haskey(s.components, name(c))
        @assert s.components[name(c)] == c "Snapshot is connected to 2 different components sharing the name $(name(c))"
    else
        s.components[name(c)] = c
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

# display snapshot info
function Base.show(io::IO, s::Snapshot)
    nc = length(components(s))
    nn = length(nodes(s))
    print(
        io, 
        "Snapshot with $nc component(s) and $nn node(s)"
    )
end
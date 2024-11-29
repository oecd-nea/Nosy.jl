"""
A snapshot contains nodes and components.
"""

struct Snapshot{T}
    sim::Sim
    components::Dict{String,Component{T}}
    nodes::Dict{String,Node{T}}
    options::Dict
end

defaultsnapshotoptions() = Dict()

function Snapshot(sim::Sim, options::Dict=defaultsnapshotoptions())
    Snapshot(
        sim,
        Dict{String,Component{AffExpr}}(),
        Dict{String,Node{AffExpr}}(),
        options
    )
end

components(s::Snapshot) = s.components
nodes(s::Snapshot) = s.nodes

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
    for n in nodes(s)
        apply_constraints!(n)
    end
end
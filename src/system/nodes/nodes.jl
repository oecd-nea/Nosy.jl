using JuMP: AffExpr

"""
Definition of nodes.

In a node, all flows are associated with the same carrier.
"""

struct Node{T<:VAL,C<:AbstractCarrier} <: AbstractElement{T}
    name::String
    carrier::C
    s::PortStructure{T}
    rule::Symbol # :curtailed or :default
end

"""
    Node(name::String, c::Carrier; rule=:default)
Construct a Node with name `name` associated with carrier `c`.
The `rule` defines the node behavior (:default, :curtailed).
"""
function Node(name::String, c::AbstractCarrier; rule=:default)
    return Node(
        name,
        c,
        PortStructure{AffExpr}(),
        rule
    )
end

name(n::Node) = n.name

carrier(n::Node) = n.carrier

rule(n::Node) = n.rule
iscurtailed(n::Node) = rule(n) == :curtailed

input(n::Node) = input(n.s)
output(n::Node) = output(n.s)

# add port to node
# check is performed on T∈VAL (must be identical), and carrier type C (must be identical)
function addinput!(n::Node{T,C}, name::String, p::Port{T,C}) where {T,C}
    @assert carrier(n) == carrier(p) "$name is not compatible with node $(POSY2.name(n))"
    addinput!(n.s, name, p)
end

function addoutput!(n::Node{T,C}, name::String, p::Port{T,C}) where {T,C}
    @assert carrier(n) == carrier(p) "$name is not compatible with node $(POSY2.name(n))"
    addoutput!(n.s, name, p)
end

# throw exception when carriers are different between node and port
addinput!(n::Node{T,C1}, name::String, ::Port{T,C2}) where {T,C1,C2} =  throw(AssertionError("$name is not compatible with node $(POSY2.name(n))"))
addoutput!(n::Node{T,C1}, name::String, ::Port{T,C2}) where {T,C1,C2} =  throw(AssertionError("$name is not compatible with node $(POSY2.name(n))"))

# cannot add level to node
addlevel!(::Node{T,C1}, ::String, ::Port{T,C2}) where {T,C1, C2} = throw(AssertionError("Ports cannot have a level"))




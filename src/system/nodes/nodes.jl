using JuMP: AffExpr
using ArgCheck: @argcheck

"""
Definition of nodes.

In a node, all flows are associated with the same carrier.
"""

# store dual price
# will not be accessed often, performance is not required here
mutable struct DualPrice{T}
    val
end

struct Node{T<:VAL,C<:AbstractCarrier} <: AbstractElement{T}
    name::String
    carrier::C
    s::PortStructure{T}
    rule::Symbol # :curtailed or :default
    evalprice::Bool
    dualprice::DualPrice{T}

    function Node(name::String, carrier::AbstractCarrier, s::PortStructure{T}, rule::Symbol, evalprice::Bool, dualprice::DualPrice{T}) where T
        @argcheck rule in NODE_RULES "Only valid node rules are: $NODE_RULES"
        new{T,typeof(carrier)}(name, carrier, s, rule, evalprice, dualprice)
    end 
end

const NODE_RULES = [:default, :curtailed]

"""
    Node(name::String, c::Carrier; rule::Symbol=:default)
Construct a Node with name `name` associated with carrier `c`.
The `rule` defines the node behavior (:default, :curtailed).
"""
function Node(name::String, c::AbstractCarrier; rule::Symbol=:default, evalprice::Bool=false)
    return Node(
        name,
        c,
        PortStructure{AffExpr}(sim(c)),
        rule,
        evalprice,
        DualPrice{AffExpr}(nothing),
    )
end

name(n::Node) = n.name

carrier(n::Node) = n.carrier

rule(n::Node) = n.rule
iscurtailed(n::Node) = rule(n) == :curtailed

portstructure(n::Node) = n.s
sim(n::Node) = sim(carrier(n))

_input(n::Node) = _input(portstructure(n))
_output(n::Node) = _output(portstructure(n))

# add port to node
# check is performed on T∈VAL (must be identical), and carrier type C (must be identical)
function addinput!(n::Node{T,C}, name::String, p::Port{T,C}) where {T,C}
    @assert carrier(n) == carrier(p) "$name is not compatible with node $(Nosy.name(n))"
    addinput!(n.s, name, p)
end

function addoutput!(n::Node{T,C}, name::String, p::Port{T,C}) where {T,C}
    @assert carrier(n) == carrier(p) "$name is not compatible with node $(Nosy.name(n))"
    addoutput!(n.s, name, p)
end

# throw exception when carriers are different between node and port
addinput!(n::Node{T,C1}, name::String, ::Port{T,C2}) where {T,C1,C2} =  throw(AssertionError("$name is not compatible with node $(Nosy.name(n))"))
addoutput!(n::Node{T,C1}, name::String, ::Port{T,C2}) where {T,C1,C2} =  throw(AssertionError("$name is not compatible with node $(Nosy.name(n))"))

# cannot add level to node
addlevel!(::Node{T,C1}, ::String, ::Port{T,C2}) where {T,C1, C2} = throw(AssertionError("Ports cannot have a level"))

# display node info
function Base.show(io::IO, n::Node)
    nin = length(_input(n))
    nout = length(_output(n))
    ntype = iscurtailed(n) ? "curtailed" : "not curtailed"
    print(
        io,
        "Node \"$(name(n))\" ($ntype) with $nin _input(s), $nout _output(s)"
    )
end
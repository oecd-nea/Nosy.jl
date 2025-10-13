using JuMP: GenericAffExpr
using ArgCheck: @argcheck, ArgumentError

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
    losses::Number
    rule::Symbol # :curtailed or :default
    evalprice::Bool
    dualprice::DualPrice{T}
    tags::Vector{Symbol}

    function Node(name::String, carrier::AbstractCarrier, s::PortStructure{T}, losses::Number, rule::Symbol, evalprice::Bool, dualprice::DualPrice{T}, tags::Vector{Symbol}) where T
        @argcheck rule in NODE_RULES "Only valid node rules are: $NODE_RULES"
        @argcheck 0 <= losses <= 1 "Losses must be be between 0 and 1"
        new{T,typeof(carrier)}(name, carrier, s, losses, rule, evalprice, dualprice, tags)
    end 
end

const NODE_RULES = [:default, :curtailed]

"""
    Node(name::String, c::Carrier; rule::Symbol=:default)
Construct a Node with name `name` associated with carrier `c`.
The `rule` defines the node behavior (:default, :curtailed).
The `losses` is a ratio (between 0 and 1) of the sum of the input that is lost.
The `tags` are the node tags.
"""
function Node(name::String, c::AbstractCarrier; losses::Number=0., rule::Symbol=:default, evalprice::Bool=false, tags::Vector{Symbol}=Symbol[])
    return Node(
        name,
        c,
        PortStructure{exptype(sim(c))}(sim(c)),
        losses,
        rule,
        evalprice,
        DualPrice{exptype(sim(c))}(nothing),
        copy(tags),
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

# this method is never ambigous
getport(n::Node, pname::String, cname::String) = _getport(portstructure(n), pname, cname)

hasinput(n::Node, pname::String, from::String) = haskey(_input(n), PortRef(from, pname))
hasoutput(n::Node, pname::String, to::String) = haskey(_output(n), PortRef(to, pname))
haslevel(::Node, ::String, ::String) = false

_haslosses(n::Node) = !iszero(n.losses)
_lossesratio(n::Node) = n.losses

tag!(n::Node, tag::Symbol) = tag in n.tags ? nothing : push!(n.tags, tag)
hastag(n::Node, tag::Symbol) = tag in n.tags

# add port to node
# check is performed on T∈VAL (must be identical), and carrier type C (must be identical)
function addinput!(n::Node{T,C}, pname::String, cname::String, p::Port{T,C}) where {T,C}
    @argcheck carrier(n) == carrier(p) "$cname is not compatible with node $(Nosy.name(n))"
    addinput!(n.s, pname, cname, p)
end

function addoutput!(n::Node{T,C}, pname::String, cname::String, p::Port{T,C}) where {T,C}
    @argcheck carrier(n) == carrier(p) "$name is not compatible with node $(Nosy.name(n))"
    addoutput!(n.s, pname, cname, p)
end

# add losses to a node
# we add an additional output, which is equal to the node input multiplied by a ratio
# NB this must be done after nodes are defined -> called during finalization of snapshot
function addlosses!(n::Node)
    if _haslosses(n)
        # losses = (node losses ratio) * (sum of input of node)
        _in = balance(n, :input, _defaultmodifier(n.carrier), aggregate=true, collapse=false)
        addoutput!(n, "losses", name(n), Port(n.carrier, _in * n.losses, true))
    end
end

# throw exception when carriers are different between node and port
addinput!(::Node{T,C1}, ::String, ::String, ::Port{T,C2}) where {T,C1,C2} =  throw(AssertionError("$name is not compatible with node $(Nosy.name(n))")) # not used ??
addoutput!(::Node{T,C1}, ::String, ::String, ::Port{T,C2}) where {T,C1,C2} =  throw(AssertionError("$name is not compatible with node $(Nosy.name(n))")) # not used ??

# cannot add level to node
addlevel!(::Node{T,C1}, ::String, ::String, ::Port{T,C2}) where {T,C1, C2} = throw(ArgumentError("Ports cannot have a level"))

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
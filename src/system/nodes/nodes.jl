using JuMP: ConstraintRef, GenericAffExpr
using ArgCheck: @argcheck, ArgumentError

"""
Definition of nodes.

In a node, all flows are associated with the same carrier.
"""

abstract type AbstractDualPrice{T} end

# Model-referencing dual price: save JuMP constraints until dual prices are extracted.
mutable struct SavedDualPrice{T<:GenericAffExpr} <: AbstractDualPrice{T}
    constraints::Union{Nothing,AbstractVector{<:ConstraintRef}}
end

# Extracted dual price: keep numeric prices without references to the JuMP model.
mutable struct DualPrice{T<:Float64} <: AbstractDualPrice{T}
    values::Union{Nothing,Vector{Float64}}
    # No price was evaluated or defined.
    DualPrice{T}(values::Nothing) where {T} = new{T}(values)
    # Already-decoupled numeric price values.
    DualPrice{T}(values::Vector{Float64}) where {T} = new{T}(values)
    # Normalize numeric vectors to the serializable value type.
    DualPrice{T}(values::AbstractVector{<:Number}) where {T} = new{T}(Float64.(values))
end

_dualpricecontainer(::Type{Float64}) = DualPrice{Float64}(nothing)
_dualpricecontainer(::Type{T}) where {T} = SavedDualPrice{T}(nothing)

struct Node{T<:VAL,C<:AbstractCarrier} <: AbstractElement{T}
    name::String
    carrier::C
    s::PortStructure{T}
    losses::Float64
    rule::Symbol # :curtailed or :default
    evalprice::Bool
    dualprice::AbstractDualPrice{T}
    tags::Vector{Symbol}

    function Node(name::String, carrier::AbstractCarrier, s::PortStructure{T}, losses::Number, rule::Symbol, evalprice::Bool, dualprice::AbstractDualPrice{T}, tags::Vector{Symbol}) where T
        @argcheck rule in NODE_RULES "Only valid node rules are: $NODE_RULES"
        @argcheck 0 <= losses <= 1 "Losses must be be between 0 and 1"
        new{T,typeof(carrier)}(name, carrier, s, losses, rule, evalprice, dualprice, tags)
    end 
end

const NODE_RULES = [:default, :curtailed]

"""
    Node(name::String, c::AbstractCarrier; losses::Number=0., rule::Symbol=:default, evalprice::Bool=false, tags::Vector{Symbol}=Symbol[])

Construct a `Node` with name `name` associated with carrier `c`. A node has a unique carrier.
The `rule` defines the node behavior (`:default` or `:curtailed`).
The `losses` value is the ratio, between 0 and 1, of input flow that is lost.
Set `evalprice=true` to store node-balance constraints for dual-price extraction.
The `tags` argument initialises the node tags.
"""
function Node(name::String, c::AbstractCarrier; losses::Number=0., rule::Symbol=:default, evalprice::Bool=false, tags::Vector{Symbol}=Symbol[])
    return Node(
        name,
        c,
        PortStructure{exptype(sim(c))}(sim(c)),
        losses,
        rule,
        evalprice,
        _dualpricecontainer(exptype(sim(c))),
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
haslevel(n::Node, pname::String, ::String) = false

function hasinput(n::Node, cname::String)
    for (k,_) in _input(n)
        k.cname == cname && return true
    end
    return false
end

function hasoutput(n::Node, cname::String)
    for (k,_) in _output(n)
        k.cname == cname && return true
    end
    return false
end

haslevel(n::Node, cname::String) = false

_haslosses(n::Node) = !iszero(n.losses)

tag!(n::Node, tag::Symbol) = tag in n.tags ? nothing : push!(n.tags, tag)
hastag(n::Node, tag::Symbol) = tag in n.tags

# add port to node
# check is performed on T∈VAL (must be identical), and carrier type C (must be identical)
function addinput!(n::Node{T,C}, pname::String, cname::String, p::Port{T,C}) where {T,C}
    @argcheck carrier(n) == carrier(p) "Port $pname is not compatible with node $(Nosy.name(n))"
    addinput!(n.s, pname, cname, p)
end

function addoutput!(n::Node{T,C}, pname::String, cname::String, p::Port{T,C}) where {T,C}
    @argcheck carrier(n) == carrier(p) "Port $pname is not compatible with node $(Nosy.name(n))"
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
addinput!(n::Node{T,C1}, pname::String, cname::String, ::Port{T,C2}) where {T,C1,C2} =  throw(AssertionError("Port $pname of $cname is not compatible with node $(Nosy.name(n))")) # not used ??
addoutput!(n::Node{T,C1}, pname::String, cname::String, ::Port{T,C2}) where {T,C1,C2} =  throw(AssertionError("Port $pname pf $cname is not compatible with node $(Nosy.name(n))")) # not used ??

# cannot add level to node
addlevel!(::Node{T,C1}, ::String, ::String, ::Port{T,C2}) where {T,C1, C2} = throw(ArgumentError("Ports cannot have a level"))

# display node info
function Base.show(io::IO, n::Node)
    nin = length(_input(n))
    nout = length(_output(n))
    ntype = iscurtailed(n) ? "curtailed" : "not curtailed"
    print(
        io,
        "Node \"$(name(n))\" ($ntype) with $nin input(s), $nout output(s)"
    )
end

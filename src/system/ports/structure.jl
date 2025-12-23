"""
PortRef.
Port reference, contains the component name and the port name.
"""

struct PortRef
    cname::String # name of component the port is emanating from (or node for losses)
    pname::String # name of port
end

(==)(pr1::PortRef, pr2::PortRef) = (pr1.pname == pr2.pname) && (pr1.cname == pr2.cname)


"""
PortDict.
Port dictionary, contains a dictionary of PortRef => Port.
Is used as a wall for type instability, so that AbstractCarrier subtype (unpredictable) does not impact PortStructure.
"""
const V{T} = Union{Port{T,MassCarrier}, Port{T,PowerCarrier}, Port{T,EnergyCarrier}, Port{T,CO2Carrier}} where T<:VAL

struct PortDict{T} <: AbstractElement{T}
    d::Dict{PortRef,Port{T}} # type instability, but probably not too impactful
end

# constructor for general case
PortDict{T}() where T = PortDict(Dict{PortRef,Port{T}}())

# constructor for _extract function
PortDict(d::Dict{PortRef,<:Port{T}}) where T = PortDict(convert(Dict{PortRef,Port{T}},d))

# Implementation of Dict ~ iterable interface
Base.getindex(d::PortDict, i) = getindex(d.d, i)
Base.setindex!(d::PortDict, i, p) = setindex!(d.d, i, p)
Base.length(d::PortDict) = length(d.d)
Base.haskey(d::PortDict, k) = haskey(d.d, k)
Base.copy(d::PortDict) = PortDict(copy(d.d))
Base.iterate(d::PortDict) = iterate(d.d)
Base.iterate(d::PortDict, s) = iterate(d.d, s)
Base.values(d::PortDict) = values(d.d)


"""
Port structure.
Contain all the ports associated with a node or model.
"""

struct PortStructure{T<:VAL} <: AbstractElement{T}
    sim::Sim
    input::PortDict{T}
    output::PortDict{T}
    level::PortDict{T}
end

# parametric constructor for PortStructure
function PortStructure{T}(s::Sim) where T<:VAL
    return PortStructure(
        s,
        PortDict{T}(),
        PortDict{T}(),
        PortDict{T}(),
    )
end

sim(ps::PortStructure) = ps.sim

function getpname(ps::PortStructure, p::Port, sense::Symbol)
    if sense == :input
        d = ps.input
    elseif sense == :output
        d = ps.output
    else
        throw(AssertionError("Sense must be :input or :output"))
    end

    for (k,v) in d
        if v == p
            return k.pname
        end
    end

    throw(AssertionError("Port with name $pname not found"))
end


function addinput!(ps::PortStructure{T}, pname::String, cname::String, p::Port{T}) where T
    hasport(ps, pname, cname) && throw(AssertionError("Port structure already connected to port $pname from component $cname")) # not just same sense
    ps.input[PortRef(cname, pname)] = p
end

function addoutput!(ps::PortStructure{T}, pname::String, cname::String, p::Port{T}) where T
    hasport(ps, pname, cname) && throw(AssertionError("Port structure already connected to port $pname from component $cname")) # not just same sense
    ps.output[PortRef(cname, pname)] = p
end

function addlevel!(ps::PortStructure{T}, pname::String, cname::String, p::Port{T}) where T
    hasport(ps, pname, cname) && throw(AssertionError("Port structure already connected to port $pname from component $cname")) # not just same sense
    ps.level[PortRef(cname, pname)] = p
end


_hasinput(ps::PortStructure, pname::String, cname::String) = haskey(_input(ps), PortRef(cname, pname))
_hasoutput(ps::PortStructure, pname::String, cname::String) = haskey(_output(ps), PortRef(cname, pname))
_haslevel(ps::PortStructure, pname::String, cname::String) = haskey(_level(ps), PortRef(cname, pname))

_input(ps::PortStructure) = ps.input
_output(ps::PortStructure) = ps.output
_level(ps::PortStructure) = ps.level


Base.isempty(ps::PortStructure) = all(isempty(d) for d in (_input(ps), _output(ps), _level(ps)))

# following implementation is probably not efficient
# return a tuple with all the ports of a PortStructure
allports(ps::PortStructure) = (values(_input(ps))..., values(_output(ps))..., values(_level(ps))...)
externalports(ps::PortStructure) = (values(_input(ps))..., values(_output(ps))...)

# return true if all the input and output ports of the port structure are used
# return false otherwise
isfullyconnected(ps::PortStructure) = all(is_used(p) for p in externalports(ps))

# return true if ps only is associated with one carrier, false otherwise
function hasuniquecarrier(ps::PortStructure)
    vp = allports(ps)
    isempty(vp) && return true # if there is no port
    c = carrier(first(vp))
    return !any(carrier(p) != c for p in allports(ps))
end

function _getport(ps::PortStructure, pname::String, cname::String)
    pr = PortRef(cname, pname)
    for d in (_input(ps), _output(ps), _level(ps))
        if haskey(d, pr)
            return d[pr]
        end
    end
    return nothing
end

function _getportsense(ps::PortStructure, sense::Symbol)
    sense == :input && return _input(ps)
    sense == :output && return _output(ps)
    sense == :level && return _level(ps)
    throw(ArgumentError("$sense must be :input, :output or :level"))
end

# slightly sped-up function with a hint for port sense
# no need to check presence of multiple ports with same name: this can't happen when sense is defined
function _getport(ps::PortStructure, pname::String, cname::String, sense::Symbol)
    pr = PortRef(cname, pname)
    d = _getportsense(ps, sense)
    if !haskey(d, pr) 
        throw(AssertionError("No port named $(pr.pname)"))
    end
    return d[pr]
end

# return true if the port structure has a port with name pname, return false otherwise
hasport(ps::PortStructure, pname::String, cname::String) = _hasport(ps, PortRef(cname, pname))
_hasport(ps::PortStructure, pr::PortRef) = any(haskey(s(ps), pr) for s in (_input, _output, _level))


function portsense(ps::PortStructure, pr::PortRef)::Symbol
    if haskey(_input(ps), pr)
        return :input
    elseif haskey(_output(ps), pr)
        return :output
    elseif haskey(_level(ps), pr)
        return :level
    else
        throw(ArgumentError("The port structure does not contain a port associated with name $pname and component $cname"))
    end
end


# return a shallow copy of the port structure
# in particular:
#  * adding a pair to ps.input etc. does not add it to the copy and vice versa
#  * modifying a value in a pair does modify it in the copy and vice versa
function shallowcopy(ps::PortStructure)
    return PortStructure(
        sim(ps),
        copy(_input(ps)),
        copy(_output(ps)),
        copy(_level(ps))
    )
end


"""
Flow at a given step.
"""

# return the flow at a given step (as opposed to given hour)
# this method is never ambiguous (both pname and cname are given - see addinput!, addoutput!, addlevel!)
function _flow(ps::PortStructure{T}, pname::String, cname::String, modifier::Function, step::Int)::T where T
    p = _getport(ps, pname, cname)
    isnothing(p) && throw(AssertionError("No port named $pname"))
    return modifier(p, step)
end

# return the flow at a given step (as opposed to given hour)
# for this method, sense is given
function _flow(ps::PortStructure{T}, pname::String, cname::String, sense::Symbol, modifier::Function, step::Int)::T where T
    p = _getport(ps, pname, cname, sense)
    isnothing(p) && throw(AssertionError("No port named $pname"))
    return modifier(p, step)
end
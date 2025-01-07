"""
Port structure.
Contain all the ports associated with a node or model.
"""

struct PortStructure{T<:VAL} <: AbstractElement{T}
    sim::Sim
    input::Dict{String,Port{T}}
    output::Dict{String,Port{T}}
    level::Dict{String,Port{T}}
end


# parametric constructor for PortStructure
function PortStructure{T}(s::Sim) where T<:VAL
    return PortStructure(
        s,
        Dict{String, Port{T}}(),
        Dict{String, Port{T}}(),
        Dict{String, Port{T}}()
    )
end

sim(ps::PortStructure) = ps.sim

# Add named port to port structure

function addinput!(ps::PortStructure{T}, name::String, p::Port{T}) where T
    if haskey(ps.input, name)
        throw(AssertionError("$name already present as an input"))
    end
    ps.input[name] = p
end

function addoutput!(ps::PortStructure{T}, name::String, p::Port{T}) where T
    if haskey(ps.output, name)
        throw(AssertionError("$name already present as an output"))
    end
    ps.output[name] = p
end

function addlevel!(ps::PortStructure{T}, name::String, p::Port{T}) where T
    if haskey(ps.level, name)
        throw(AssertionError("$name already present as a level"))
    end
    ps.level[name] = p
end

# return true if sense of PortStructure contains port with name `name`
# NB check on the actual port is not performed, only the name is checked
hasinput(ps::PortStructure, name::String) = haskey(ps.input, name)
hasoutput(ps::PortStructure, name::String) = haskey(ps.output, name)
haslevel(ps::PortStructure, name::String) = haskey(ps.level, name)

_input(ps::PortStructure) = ps.input
_output(ps::PortStructure) = ps.output
_level(ps::PortStructure) = ps.level

Base.isempty(ps::PortStructure) = all(isempty(d) for d in (ps.input, ps.output, ps.level))

# following implementation is probably not efficient
# return a tuple with all the ports of a PortStructure
allports(ps::PortStructure) = (values(ps.input)..., values(ps.output)..., values(ps.level)...)
externalports(ps::PortStructure) = (values(ps.input)..., values(ps.output)...)

# return true if all the input and output ports of the port structure are used
# return false otherwise
isfullyconnected(ps::PortStructure) = all(is_used(p) for p in externalports(ps))

# return true if ps only is associated with one carrier, false otherwise
function hasuniquecarrier(ps::PortStructure)
    c = carrier(first(allports(ps)))
    return !any(carrier(p) != c for p in allports(ps))
end

# return the port associated with name pname
# return nothing if there is no such port
# if checkunique, throw an error if ps contains multiple ports named pname
function getport(ps::PortStructure, pname::String, checkunique::Bool=false)
    local found = false
    local p = nothing
    for d in (_input(ps), _output(ps), _level(ps))
        if haskey(d, pname)
            p = d[pname]
            if checkunique
                found && throw(AssertionError("Port structure contains multiple ports with name $pname"))
                found = true
            else
                break
            end
        end
    end
    return p
end

function getportsense(ps::PortStructure, sense::Symbol)
    sense == :input && return _input(ps)
    sense == :output && return _output(ps)
    sense == :level && return _level(ps)
    throw(ArgumentError("$s must be :input, :output or :level"))
end

# slightly sped-up function with a hint for port sense
# no need to check presence of multiple ports with same name: this can't happen when sense is defined
function getport(ps::PortStructure, pname::String, sense::Symbol)
    d = getportsense(ps, sense)
    @assert haskey(d, pname) "No port named $pname"
    return d[pname]
end

# return true if the port structure has a port with name pname, return false otherwise
hasport(ps::PortStructure, pname::String) = any(haskey(s(ps), pname) for s in (_input, _output, _level))

function portsense(ps::PortStructure, pname::String)::Symbol
    if haskey(_input(ps), pname)
        return :input
    elseif haskey(_output(ps), pname)
        return :output
    elseif haskey(_level(ps), pname)
        return :level
    else
        throw(ArgumentError("The port structure does not contain a node with name $pname"))
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
#for this method, sense is not given, therefore pname ambiguity must be checked
function _flow(ps::PortStructure{T}, pname::String, modifier::Function, step::Int)::T where T
    p = getport(ps, pname, true) # throw an error if pname is ambiguous (e.g. exists in both input/output of ps)
    isnothing(p) && throw(AssertionError("No port named $pname"))
    return modifier(p, step)
end

# return the flow at a given step (as opposed to given hour)
# for this method, sense is given
function _flow(ps::PortStructure{T}, pname::String, sense::Symbol, modifier::Function, step::Int)::T where T
    p = getport(ps, pname, sense)
    isnothing(p) && throw(AssertionError("No port named $pname"))
    return modifier(p, step)
end
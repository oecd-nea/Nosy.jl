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

input(ps::PortStructure) = ps.input
output(ps::PortStructure) = ps.output
level(ps::PortStructure) = ps.level

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
function getport(ps::PortStructure, pname::String)
    for s in (input, output, level)
        d = s(ps)
        if haskey(d, pname)
            return d[pname]
        end
    end
end

# slightly sped-up function with a hint for port sense
function getport(ps::PortStructure, pname::String, sense::Symbol)
    if sense == :input
        d = input(ps)
    elseif sense == :output
        d = output(ps)
    elseif sense == :level
        d = level(ps)
    else
        throw(ArgumentError("hint must be :input, :output or :level"))
    end
    return d[pname]
end

# return true if the port structure has a port with name pname, return false otherwise
hasport(ps::PortStructure, pname::String) = any(haskey(s(ps), pname) for s in (input, output, level))

function portsense(ps::PortStructure, pname::String)::Symbol
    if haskey(input(ps), pname)
        return :input
    elseif haskey(output(ps), pname)
        return :output
    elseif haskey(level(ps), pname)
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
        copy(input(ps)),
        copy(output(ps)),
        copy(level(ps))
    )
end
"""
Port structure.
Contain all the ports associated with a node or model.
"""

struct PortStructure{T<:VAL}
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

# return true if ps only is associated with one carrier, false otherwise
function hasuniquecarrier(ps::PortStructure)
    c = carrier(first(allports(ps)))
    for p in allports(ps)
        if carrier(p) != c
            return false
        end
    end
    return true
end

# return the port associated with name pname
function getport(ps::PortStructure, pname::String)
    for s in (input, output, level)
        d = s(ps)
        if haskey(d, pname)
            return d[pname]
        end
    end
end

# return true if the port structure has a port with name pname, return false otherwise
function hasport(ps::PortStructure, pname::String)
    for s in (input, output, level)
        d = s(ps)
        if haskey(d, pname)
            return true
        end
    end
    return false
end
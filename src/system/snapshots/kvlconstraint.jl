using JuMP: @constraint
using Graphs: SimpleGraph, cycle_basis, add_edge!
using ArgCheck: @argcheck


"""
Implementation of the KVL constraint
"""


# put KVL at snapshot level so cycles are enforced globally
# for each cycle in the AC network, apply KVL constraint: sum(flow_ij / B_ij) = 0
function add_kvl_constraints!(s::Snapshot)
    # build B-matrix (admittance matrix) from AC lines only
    # DC lines are excluded because KVL doesn't apply to DC circuits
    mat, nodelist, node_map = getintercocapacitymatrix(s)
    
    # find minimal set of independent cycles using cycle basis
    # this avoids redundant constraints: if we have N cycles, we only need to enforce KVL on a basis
    cycles = gencycles(mat)

    for c in cycles
        # initialize expression for this cycle: sum(flow_ij / B_ij) over all edges in cycle
        kvl_mesh = _cycle_kvl_mesh(s, c, nodelist, node_map)
        exp = Nosy.differentzerovector(JuMP.AffExpr, Nosy.nsteps(kvl_mesh))
        for i in eachindex(c)
            vi = c[i]
            # wrap around: last vertex connects back to first to close the cycle
            vj = (i < length(c)) ? c[i+1] : c[1]

            Bij = mat[vi, vj]
            if Bij <= 0.0 
                throw(AssertionError("No AC line between nodes $(nodelist[vi]) and $(nodelist[vj]) in AC matrix."))
            end

            from = nodelist[vi]
            to = nodelist[vj]

            # KVL: sum(flow_ij / B_ij) = 0
            # flow_ij is net flow (forward - reverse) for bidirectional lines
            # divide by admittance B_ij to get voltage drop: V = flow / B
            add_to_expression!.(exp, (_transmissionbalance(s, from, to, node_map; target=kvl_mesh, ac_only=true) / Bij).data)
        end
        # enforce KVL constraint: sum of voltage drops around cycle must be zero
        @constraint(s.sim.model, exp .== 0.0)
    end
end

# find nodes connected to a line component's ports
function _find_connected_nodes(s::Snapshot, cname::String, m::Union{ACLineModel,DCLineModel})
    nnames = String[]
    from_c = m.data.from
    to_c = m.data.to
    
    for (nname, n) in nodes(s)
        if carrier(n) == from_c || carrier(n) == to_c
            ps = portstructure(n)
            # check if node has any port connected to this line component
            if _hasinput(ps, "from_out", cname) || _hasoutput(ps, "from_in", cname) ||
               _hasinput(ps, "to_out", cname) || _hasoutput(ps, "to_in", cname)
                push!(nnames, nname)
            end
        end
    end
    
    return nnames
end

# build B-matrix only from ACLineModel to keep DC paths out of cycles
# B-matrix (admittance matrix) represents AC network topology
# DC lines are excluded because KVL doesn't apply to DC circuits in AC analysis
function getintercocapacitymatrix(s::Snapshot)
    aclines = Tuple{ACLineModel,String}[]  
    for (cname, comp) in components(s)
        m = model(comp)
        m isa ACLineModel && push!(aclines, (m, cname))
    end

    nodelist = collect(keys(nodes(s)))
    nodeindex = Dict(n => i for (i,n) in enumerate(nodelist))
    N = length(nodelist)
    mat = zeros(Float64, N, N)
    # cache node connections to avoid repeated lookups
    node_map = Dict{String, Tuple{String, String}}()  # cname => (from, to)

    for (ac, cname) in aclines
        nnames = _find_connected_nodes(s, cname, ac)
        if length(nnames) == 2
            from = nnames[1]
            to = nnames[2]
            node_map[cname] = (from, to)  
            i = nodeindex[from]
            j = nodeindex[to]
            val = ac.data.admittance
            # symmetric matrix (undirected graph)
            mat[i,j] = val
            mat[j,i] = val
        end
    end

    return mat, nodelist, node_map
end

# use undirected cycle basis to find minimal set of independent cycles
function gencycles(mat::Matrix{Float64})
    N = size(mat, 1)

    g = SimpleGraph(N)
    # build graph: edge exists if admittance > 0 (AC line present)
    for i in 1:N, j in (i+1):N
        if mat[i, j] > 0.0
            add_edge!(g, i, j)
        end
    end

    return cycle_basis(g)  
end

function _cycle_kvl_mesh(s::Snapshot, cycle, nodelist, node_map)
    meshes = RTimeMesh[]

    for i in eachindex(cycle)
        vi = cycle[i]
        vj = (i < length(cycle)) ? cycle[i+1] : cycle[1]
        for (_, line) in _transmissionlines(s, nodelist[vi], nodelist[vj], node_map; ac_only=true)
            push!(meshes, mesh(line))
        end
    end

    @assert !isempty(meshes)

    target = first(meshes)
    for m in meshes
        if nsteps(m) < nsteps(target)
            target = m
        end
    end

    for m in meshes
        @argcheck _containsmesh(m, target) "KVL cycle line meshes must have aligned boundaries"
    end

    return target
end

function _transmissionlines(s::Snapshot, from::String, to::String, node_map::Union{Dict{String, Tuple{String, String}}, Nothing}=nothing; ac_only::Bool=false)
    lines = Tuple{String,Union{ACLineModel,DCLineModel}}[]

    for (cname, comp) in components(s)
        m = model(comp)
        if m isa ACLineModel || (!ac_only && m isa DCLineModel)
            _transmissionline_matches(s, cname, m, from, to, node_map) || continue
            push!(lines, (cname, m))
        end
    end

    return lines
end

# return net power flow between two nodes (from->to)
# net flow = forward flow - reverse flow (bidirectional lines)
# multiple lines can connect the same two nodes, so we sum their net flows
function _transmissionbalance(s::Snapshot, from::String, to::String, node_map::Union{Dict{String, Tuple{String, String}}, Nothing}=nothing; target::Union{Nothing,TimeMesh}=nothing, ac_only::Bool=false)
    net = nothing

    for (cname, m) in _transmissionlines(s, from, to, node_map; ac_only=ac_only)
        p_from_out = _getport(m.s, "from_out", cname, :output)
        p_to_out = _getport(m.s, "to_out", cname, :output)

        mod_from_out = _defaultmodifier(carrierstyle(carrier(p_from_out)))
        mod_to_out = _defaultmodifier(carrierstyle(carrier(p_to_out)))

        f_ft = mod_from_out(p_from_out)
        f_tf = mod_to_out(p_to_out)

        from_n = nodes(s)[from]

        # determine line orientation to compute net flow correctly
        # lines are bidirectional, so we need to know which side each node is on
        from_side = _hasinput(portstructure(from_n), "from_out", cname)

        if from_side
            # from node on "from" side: net = f_ft - f_tf
            flow = f_ft .- f_tf
        else
            # from node on "to" side: net = f_tf - f_ft
            flow = f_tf .- f_ft
        end

        if !isnothing(target) && mesh(flow) != target
            flow = remesh(flow, target)
        end

        net = isnothing(net) ? flow : (net .+ flow)
    end
    
    isnothing(net) && throw(AssertionError("No transmission line between $from and $to"))
    return net
end

function _transmissionline_matches(s::Snapshot, cname::String, m::Union{ACLineModel,DCLineModel}, from::String, to::String, node_map::Union{Dict{String, Tuple{String, String}}, Nothing})
    # use cached node_map if available for efficiency
    if isnothing(node_map) || !haskey(node_map, cname)
        nnames = _find_connected_nodes(s, cname, m)
        return length(nnames) == 2 && from in nnames && to in nnames
    else
        cached_from, cached_to = node_map[cname]
        # check both directions (lines are bidirectional)
        return (from, to) == (cached_from, cached_to) || (from, to) == (cached_to, cached_from)
    end
end
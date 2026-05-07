"""
Reserve metrics for snapshots
"""

"""
    reserve(snap::Snapshot{T}, sense::Symbol, rname::String; with::Vector{Symbol}=Symbol[], without::Vector{Symbol}=Symbol[]) where T

Return the total reserve of components in Snapshot `snap` for the specified `sense` and reserve name `rname`.
Optional `with` and `without` filter components by tags (same as `getcomponents(snap; with, without)`).
"""
function reserve(snap::Snapshot{T}, sense::Symbol, rname::String; with::Vector{Symbol}=Symbol[], without::Vector{Symbol}=Symbol[]) where T
    comps = values(getcomponents(snap; with=with, without=without))
    if isempty(comps)
        return Stepwise(differentzerovector(T, nsteps(sim(snap).mesh)), sim(snap).mesh)
    end
    return sum(reserve(c, sense, rname) for c in comps)
end

"""
    reserve(snap::Snapshot{T}, name::String, sense::Symbol, rname::String; with::Vector{Symbol}=Symbol[], without::Vector{Symbol}=Symbol[]) where T

Return the reserve of the component named `name`, or the total reserve of components connected to node named `name`, within Snapshot `snap` for the specified `sense` and reserve name `rname`.
When `name` is a node, optional `with` and `without` filter components by tags.
"""
function reserve(snap::Snapshot{T}, name::String, sense::Symbol, rname::String; with::Vector{Symbol}=Symbol[], without::Vector{Symbol}=Symbol[]) where T
    if hascomponent(snap, name)
        return reserve(getcomponent(snap, name), sense, rname)
    elseif hasnode(snap, name)
        comps = values(getcomponents(snap, name; with=with, without=without))
        if isempty(comps)
            return Stepwise(differentzerovector(T, nsteps(sim(snap).mesh)), sim(snap).mesh)
        end
        return sum(reserve(c, sense, rname) for c in comps)
    else
        return Stepwise(differentzerovector(T, nsteps(sim(snap).mesh)), sim(snap).mesh)
    end
end

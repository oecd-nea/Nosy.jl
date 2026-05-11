"""
    cost(s::Snapshot, cname::String)

Return the cost of Component with name `cname` in Snapshot `s`.
If the component has no cost, return zero.
Throw an error if there is no component with name `cname` in `s`.
"""
cost(s::Snapshot, cname::String) = _applymetric(s, cname, cost)

"""
    cost(s::Snapshot, cname::String, type::Symbol)

Return the cost of type `type` of Component with name `cname` in Snapshot `s`.
If the component has no cost, return zero.
Throw an error if there is no component with name `cname` in `s`.
"""
cost(s::Snapshot, cname::String, type::Symbol) = _applymetric(s, cname, cost, type)

"""
    cost(s::Snapshot)

Return the sum of the costs of the components of the Snapshot.
"""
cost(s::Snapshot{T}) where T = sum((cost(s, cname) for cname in keys(s.components)), init=zero(T))

"""
    cost(s::Snapshot, type::Symbol)

Return the sum of the costs of type `type` of the components of the Snapshot.
"""
cost(s::Snapshot{T}, type::Symbol) where T = sum((cost(s, cname, type) for cname in keys(s.components)), init=zero(T))


# all the cost items behave the same way
# using code generation to reduce size
for (metric, comment) in COST_COMPONENT_METRICS
    mname = Symbol(metric)
    @eval begin

        @doc """
            $($mname)(s::Snapshot, cname::String)

        Return the $($comment) of Component with name `cname` in Snapshot `s`.
        If the component has no $($comment), return zero.
        Throw an error if there is no component with name `cname` in `s`.
        """
        $(mname)(s::Snapshot, cname::String) = _applymetric(s, cname, $(mname))

        @doc """
            $($mname)(s::Snapshot, cname::String, type::Symbol)

        Return the $($comment) of type `type` of Component with name `cname` in Snapshot `s`.
        If the component has no $($comment) of type `type`, return zero.
        Throw an error if there is no component with name `cname` in `s`.
        """
        $(mname)(s::Snapshot, cname::String, type::Symbol) = _applymetric(s, cname, $(mname), type)


        @doc """
            $($mname)(s::Snapshot)

        Return the sum of $($comment) items of the components of `s`.
        """
        $(mname)(s::Snapshot{T}) where T = sum(($(mname)(s, cname) for cname in keys(s.components)); init=zero(T))

        @doc """
            $($mname)(s::Snapshot, type::Symbol)

        Return the sum of $($comment) items of type `type` of the components of `s`.
        """
        $(mname)(s::Snapshot{T}, type::Symbol) where T = sum(($(mname)(s, cname, type) for cname in keys(s.components)); init=zero(T))

    end

end


# return a Vector{Symbol} containing all the user-defined cost types of the Snapshot
function _costtypes(s::Snapshot)
    ctypes = Vector{Symbol}(undef,0)
    for (_,c) in s.components
        for b in getbehaviors(c, AbstractCostBehavior)
            ctype = _costtype(b)
            if !(ctype in ctypes)
                push!(ctypes, ctype)
            end
        end
    end
    return sort(ctypes) # sort to maintain same order across different snapshots
end
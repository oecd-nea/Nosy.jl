"""
Generate a table for a given metric.
"""

using DataFrames

"""
    table(s::Snapshot, metric::Function)
Return a table containing the evaluation of the metric `metric` over the components of Snapshot `s`.
If `removenothing` is true, the values equal to nothing will be discarded.
"""
function table(s::Snapshot{T}, metric::Function; removenothing::Bool=true) where T
    d = Dict{String,Union{Nothing,T}}()
    for (k,v) in s.components
        m = metric(v)
        if !removenothing || !isnothing(m)
            d[k] = m
        end
    end
    return DataFrame(d)
end

"""
    costs(s::Snapshot; removezero::Bool=true, addtotal::Bool=true)
Return a DataFrame containing the detail of all the cost items of all the components of Snapshot `s`.
If `removezero`, components with costs equal to zero will not appear.
If `addtotal`, sums over components and cost types will also be provided.
"""
function costs(s::Snapshot; removezero::Bool=false, addtotal::Bool=true)
    ctypes = _costtypes(s)
    df = DataFrame()
    df[!,"component"] = sort(collect(keys(components(s)))) # sort to get consistent order across different snapshot with similar components
    _ctypes = Symbol[]
    for ctype in ctypes
        vc = [cost(s, cname, ctype) for cname in df[!,"component"]]
        if !removezero || !all(iszero(c) for c in vc)
            df[!,ctype] = vc
            push!(_ctypes, ctype)
        end
    end

    if addtotal
        push!(df, Dict(:component => "all", (col => cost(s, col) for col in _ctypes)...))
        df[!,:total] = sum(df[!,col] for col in _ctypes)
    end

    return df
end
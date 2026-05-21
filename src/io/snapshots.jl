"""
Lightweight snapshot serialization.

Why:
    Extracted snapshots are often used later for reporting, plotting, and
    comparison. They do not need the JuMP model anymore, and keeping it makes
    exported files very large. It also keeps solver/model internals and objects
    from the environment that created the snapshot.

What:
    `exportsnapshot` stores only `Snapshot{Float64}` objects, which are the
    extracted numerical results of an optimized snapshot. Before serialization,
    it temporarily detaches the JuMP model, removes non-portable option values,
    and replaces captured implementation functions with a Nosy-owned placeholder.
    The in-memory snapshot is restored after export.

How:
    The sanitizer walks only the result-bearing Nosy objects that can contain
    environment-specific payloads. Heavy shared structures such as `Sim`,
    carriers, ports, and time-series data are treated as leaves, while plain
    arrays, tuples, dictionaries, and Nosy-owned behavior/joint-flow structs are
    copied only when a field actually changes. This keeps export fast, avoids
    serializing external package internals, and lets imported snapshots be used
    for post-processing without the original project environment.
"""

using Serialization: deserialize, serialize
using ConstructionBase: constructorof

# Fail if stripped functions are called.
function _exported_snapshot_function(args...; kwargs...)
    throw(ArgumentError("Imported snapshots keep their extracted values, but exported implementation functions are not available."))
end

# Keep functions that serialize portably.
_exportsnapshot_portable_function(f::Function) =
    parentmodule(typeof(f)) in (@__MODULE__, Base, Core)

# Select which values the sanitizer should recurse into.
_exportsnapshot_walks_value(x) = parentmodule(typeof(x)) == @__MODULE__
_exportsnapshot_walks_value(::Sim) = false
_exportsnapshot_walks_value(::AbstractCarrier) = false
_exportsnapshot_walks_value(::Stepwise) = false
_exportsnapshot_walks_value(::Port) = false
_exportsnapshot_walks_value(::PortStructure) = false
_exportsnapshot_walks_value(x::AbstractVector) = true
_exportsnapshot_walks_value(x::Tuple) = true
_exportsnapshot_walks_value(x::AbstractDict) = true
_exportsnapshot_walks_value(x::Function) = true

# Start a fresh sanitizer walk.
_exportsnapshot_sanitize_value(x) =
    _exportsnapshot_sanitize_value(x, IdDict{Any,Any}())

# Recursively sanitize values while preserving unchanged objects.
function _exportsnapshot_sanitize_value(x::Union{Nothing,Bool,Number,String,Symbol,Type}, ::IdDict)
    return x
end

function _exportsnapshot_sanitize_value(f::Function, ::IdDict)
    return _exportsnapshot_portable_function(f) ? f : _exported_snapshot_function
end

function _exportsnapshot_sanitize_value(v::AbstractVector{<:Union{Bool,Number,String,Symbol}}, ::IdDict)
    return v
end

function _exportsnapshot_sanitize_value(t::Tuple, seen::IdDict)
    sanitized = map(x -> _exportsnapshot_sanitize_value(x, seen), t)
    all(new === old for (new, old) in zip(sanitized, t)) && return t
    return sanitized
end

function _exportsnapshot_sanitize_value(v::AbstractVector, seen::IdDict)
    haskey(seen, v) && return seen[v]
    sanitized = map(x -> _exportsnapshot_sanitize_value(x, seen), v)
    all(new === old for (new, old) in zip(sanitized, v)) && return v
    newvalue = try
        constructorof(typeof(v))(sanitized)
    catch
        sanitized
    end
    seen[v] = newvalue
    return newvalue
end

function _exportsnapshot_sanitize_value(d::AbstractDict, seen::IdDict)
    haskey(seen, d) && return seen[d]
    sanitized = Dict{Any,Any}()
    changed = false
    for (key, value) in d
        newkey = _exportsnapshot_sanitize_value(key, seen)
        newvalue = _exportsnapshot_sanitize_value(value, seen)
        changed |= newkey !== key || newvalue !== value
        sanitized[newkey] = newvalue
    end
    changed || return d
    newvalue = try
        constructorof(typeof(d))(sanitized)
    catch
        sanitized
    end
    seen[d] = newvalue
    return newvalue
end

function _exportsnapshot_sanitize_value(x, seen::IdDict)
    isstructtype(typeof(x)) || return x
    _exportsnapshot_walks_value(x) || return x
    haskey(seen, x) && return seen[x]

    sanitized = Any[]
    changed = false
    for field in fieldnames(typeof(x))
        isdefined(x, field) || return x
        value = getfield(x, field)
        newvalue = _exportsnapshot_sanitize_value(value, seen)
        changed |= newvalue !== value
        push!(sanitized, newvalue)
    end
    changed || return x

    newvalue = try
        constructorof(typeof(x))(sanitized...)
    catch
        x
    end
    seen[x] = newvalue
    return newvalue
end

# Copy a sanitized component.
function _exportsnapshot_sanitize_component(c::Component{Float64})
    seen = IdDict{Any,Any}()
    return Component(
        c.name,
        _exportsnapshot_sanitize_value(c.model, seen),
        Vector{AbstractRegularBehavior{Float64}}(_exportsnapshot_sanitize_value.(c.behaviors, Ref(seen))),
        Vector{AbstractJointFlow{Float64}}(_exportsnapshot_sanitize_value.(c.jointflows, Ref(seen))),
        c.tags,
        c.s,
    )
end

# Swap in sanitized components.
function _exportsnapshot_sanitize_components!(s::Snapshot{Float64})
    original = copy(s.components)
    for (name, component) in original
        s.components[name] = _exportsnapshot_sanitize_component(component)
    end
    return original
end

# Restore original components.
function _exportsnapshot_restore_components!(s::Snapshot{Float64}, original)
    empty!(s.components)
    merge!(s.components, original)
    return nothing
end

# Keep simple option values.
_exportsnapshot_option_value(x::Union{Nothing,Bool,Number,String,Symbol}) = (true, x)

# Sanitize option tuples.
function _exportsnapshot_option_value(x::Tuple)
    values = Any[]
    for v in x
        keep, value = _exportsnapshot_option_value(v)
        keep || return (false, nothing)
        push!(values, value)
    end
    return (true, tuple(values...))
end

# Sanitize option vectors.
function _exportsnapshot_option_value(x::AbstractVector)
    values = Any[]
    for v in x
        keep, value = _exportsnapshot_option_value(v)
        keep || return (false, nothing)
        push!(values, value)
    end
    return (true, values)
end

# Sanitize option dictionaries.
function _exportsnapshot_option_value(x::AbstractDict)
    values = Dict{Any,Any}()
    for (k, v) in x
        keepkey, key = _exportsnapshot_option_value(k)
        keepvalue, value = _exportsnapshot_option_value(v)
        (keepkey && keepvalue) || return (false, nothing)
        values[key] = value
    end
    return (true, values)
end

# Drop complex option values.
_exportsnapshot_option_value(_) = (false, nothing)

# Swap in portable options.
function _exportsnapshot_sanitize_options!(options::Dict)
    original = copy(options)
    empty!(options)
    for (key, value) in original
        keep, sanitized = _exportsnapshot_option_value(value)
        keep && (options[key] = sanitized)
    end
    return original
end

# Restore original options.
function _exportsnapshot_restore_options!(options::Dict, original::Dict)
    empty!(options)
    merge!(options, original)
    return nothing
end

# Normalize export paths.
function _exportsnapshot_path(path::AbstractString)
    _, ext = splitext(path)
    isempty(ext) && return string(path, ".snap")
    ext == ".snap" || throw(ArgumentError("Snapshot export extension should be .snap"))
    return path
end

"""
    exportsnapshot(path, snapshot)
    exportsnapshot(io, snapshot)

Serialize an extracted `Snapshot{Float64}` after removing its JuMP model.

Path exports require a `.snap` extension. If no extension is provided,
`.snap` is appended.

The original snapshot keeps its model after export. Imported snapshots are meant
for reporting and post-processing, not for further optimization.
"""
function exportsnapshot(io::IO, s::Snapshot{Float64})
    oldmodel = sim(s).model
    oldcomponents = _exportsnapshot_sanitize_components!(s)
    oldsnapshotoptions = _exportsnapshot_sanitize_options!(s.options)
    oldsimoptions = _exportsnapshot_sanitize_options!(sim(s).options)
    sim(s).model = nothing
    try
        serialize(io, s)
    finally
        sim(s).model = oldmodel
        _exportsnapshot_restore_components!(s, oldcomponents)
        _exportsnapshot_restore_options!(s.options, oldsnapshotoptions)
        _exportsnapshot_restore_options!(sim(s).options, oldsimoptions)
    end
    return nothing
end

# Export to a filesystem path.
function exportsnapshot(path::AbstractString, s::Snapshot{Float64})
    exportpath = _exportsnapshot_path(path)
    open(exportpath, "w") do io
        exportsnapshot(io, s)
    end
    return nothing
end

# Support snapshot-first argument order.
exportsnapshot(s::Snapshot{Float64}, path::AbstractString) = exportsnapshot(path, s)

# Reject non-extracted snapshots.
exportsnapshot(::Union{IO,AbstractString}, ::Snapshot) =
    throw(ArgumentError("Only Snapshot{Float64} can be exported. Call extract on an optimized snapshot first."))

# Reject non-extracted snapshots.
exportsnapshot(::Snapshot, ::AbstractString) =
    throw(ArgumentError("Only Snapshot{Float64} can be exported. Call extract on an optimized snapshot first."))

"""
    importsnapshot(path)
    importsnapshot(io)

Deserialize a lightweight `Snapshot{Float64}` exported with `exportsnapshot`.
"""
function importsnapshot(io::IO)
    s = deserialize(io)
    s isa Snapshot{Float64} ||
        throw(ArgumentError("Serialized object is not a Snapshot{Float64}"))
    return s
end

# Import from a filesystem path.
function importsnapshot(path::AbstractString)
    open(path, "r") do io
        importsnapshot(io)
    end
end

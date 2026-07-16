"""
Components.
"""

struct Component{T<:VAL,M<:AbstractModel} <: AbstractComponent{T}
    name::String
    model::M
    behaviors::Vector{AbstractRegularBehavior{T}} # NB this is an abstract type, performance impact
    jointflows::Vector{AbstractJointFlow{T}}
    tags::Dict{Symbol, Vector{String}} # key-value metadata for post-processing etc.
    s::PortStructure{T} # shallow copy of the port structure of the underlying model
end

"""
    model(c::Component)

Return the model built for component `c`.
"""
model(c::Component) = c.model

name(c::Component) = c.name
behaviors(c::Component) = c.behaviors
sim(c::Component) = sim((model(c)))
mesh(c::Component) = mesh(model(c))

hasport(c::Component, pname::String) = hasport(c.s, pname, name(c))
hasinput(c::Component, pname::String) = _hasinput(c.s, pname, name(c))
hasoutput(c::Component, pname::String) = _hasoutput(c.s, pname, name(c))
haslevel(c::Component, pname::String) = _haslevel(c.s, pname, name(c))

"""
    tag!(c::Component, k::Symbol, v::String)

Add tag value `v` under key `k` on component `c`.

Multiple values may be stored under the same key. Duplicate values are ignored.
"""
function tag!(c::Component, k::Symbol, v::String)
    if haskey(c.tags, k)
        v in c.tags[k] || push!(c.tags[k], v)
    else
        c.tags[k] = [v]
    end
    return nothing
end

"""
    hastag(c::Component, k::Symbol, v::String)

Return whether component `c` has tag value `v` under key `k`.
"""
hastag(c::Component, k::Symbol, v::String) = haskey(c.tags, k) && v in c.tags[k]

# dispatch on model (e.g. ProfileSource has a different implementation)
_addbehavior!(c::Component, b::AbstractBehavior) = _addbehavior!(c, b, model(c))

# build behavior from behavior data and component
# and add it to component behaviors
function _addbehavior!(c::Component, b::AbstractBehavior, ::AbstractModel)
    push!(c.behaviors, b)
end

"""
    Component(name::String, model::AbstractModelData, behaviors::AbstractVector; tags::Dict{Symbol, Vector{String}}=Dict{Symbol, Vector{String}}())

Construct a `Component` with name `name`, model archetype `model`, behaviors and joint flows from `behaviors`, and optional `tags`.
"""
function Component(name::String, model::AbstractModelData, behaviors::AbstractVector=[]; tags::Dict{Symbol, Vector{String}}=Dict{Symbol, Vector{String}}())
    
    _assert_unreserved_component_name(name)
    
    # fail fast when behavior duplicates are found
    _assert_unique_behaviordata(behaviors)

    m = build(model, name)
    
    c = Component(
        name, 
        m,
        Vector{AbstractRegularBehavior{exptype(sim(m))}}(undef,0),
        Vector{AbstractJointFlow{exptype(sim(m))}}(undef,0),
        Dict(k => copy(v) for (k, v) in tags),
        shallowcopy(portstructure(m))
    )

    # some behaviors must be applied before others
    # e.g. capacity behavior must come before fixed cost behavior
    # because fixed cost is based on capacity
    # joint flows take highest priority: they are build before the regular behaviors
    # priority within joint flows is given by user input
    vbehaviordata = _sortbehaviordata(behaviors, m)
    for b in vbehaviordata
        # build behavior from behavior data
        # then append it to c.behaviors
        _buildaddbehavior!(c, b)
    end

    _apply_constraints!(c)

    return c
end

# fallback for buildbehavior: build the behavior according the the model, not the component
buildbehavior(c::AbstractComponent, b::AbstractBehaviorData) = buildbehavior(model(c), name(c), b)

# build the behavior
# append it to the behaviors vector of the component
function _buildaddbehavior!(c::Component, b::AbstractBehaviorData)
    bm = buildbehavior(c, b)

    _addbehavior!(c, bm)

end

# fallback if this function is not implemented
_apply_constraints!(::AbstractComponent, m::AbstractModel) = _apply_constraints!(m) 


# apply the constraints to a component
# constraints are from:
#  * the model
#  * the behaviors
function _apply_constraints!(c::Component{<:GenericAffExpr})

    # model constraints
    _apply_constraints!(c, model(c))

    #  behaviors constraints
    for b in behaviors(c)
        _apply_constraints!(c, b)
    end

end

# display component info
function Base.show(io::IO, c::Component)
    bs = isempty(behaviors(c)) ? "" : " (" * join([behaviorname(b) for b in behaviors(c)], ", ") * ")"
    nj = length(c.jointflows)
    print(
        io, 
        "Component \"$(name(c))\" based on $(modelname(model(c))) with $nj joint flow(s) and $(length(behaviors(c))) behavior(s)$bs"
    )
end

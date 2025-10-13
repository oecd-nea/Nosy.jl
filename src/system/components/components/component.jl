"""
Components.
"""

struct Component{T<:VAL,M<:AbstractModel} <: AbstractComponent{T}
    name::String
    model::M
    behaviors::Vector{AbstractRegularBehavior{T}} # NB this is an abstract type, performance impact
    jointflows::Vector{AbstractJointFlow{T}}
    tags::Vector{Symbol} # lightweight tagging system for post-processing etc.
    s::PortStructure{T} # shallow copy of the port structure of the underlying model
end

model(c::Component) = c.model
name(c::Component) = c.name
behaviors(c::Component) = c.behaviors
sim(c::Component) = sim((model(c)))

hasport(c::Component, pname::String) = hasport(c.s, pname, name(c))
hasinput(c::Component, pname::String) = _hasinput(c.s, pname, name(c))
hasoutput(c::Component, pname::String) = _hasoutput(c.s, pname, name(c))
haslevel(c::Component, pname::String) = _haslevel(c.s, pname, name(c))


tag!(c::Component, tag::Symbol) = tag in c.tags ? nothing : push!(c.tags, tag)
hastag(c::Component, tag::Symbol) = tag in c.tags

# dispatch on model (e.g. ProfileSource has a different implementation)
_addbehavior!(c::Component, b::AbstractBehavior) = _addbehavior!(c, b, model(c))

# build behavior from behavior data and component
# and add it to component behaviors
function _addbehavior!(c::Component, b::AbstractBehavior, ::AbstractModel)
    push!(c.behaviors, b)
end

"""
    Component(name::String, model::AbstractModelData, behaviors::AbstractVector; tags::Vector{Symbol}=Symbol[])
Component constructor. Return a Component with name `name`, based on model `model` and bearing behaviors `behaviors`, tagged with `tags`.
"""
function Component(name::String, model::AbstractModelData, behaviors::AbstractVector; tags::Vector{Symbol}=Symbol[])
    
    @argcheck !_is_reserved_component_name(name) "Cannot name component $name (reserved name)"

    m = build(model, name)
    
    c = Component(
        name, 
        m,
        Vector{AbstractRegularBehavior{exptype(sim(m))}}(undef,0),
        Vector{AbstractJointFlow{exptype(sim(m))}}(undef,0),
        copy(tags),
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
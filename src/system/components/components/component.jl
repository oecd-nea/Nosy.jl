"""
Components.
"""


struct Component{T<:VAL,M<:AbstractModel} <: AbstractComponent{T}
    name::String
    model::M
    behaviors::Vector{AbstractBehavior{T}} # NB this is an abstract type, performance impact
    # jointflows::Vector{AbstractModel{T}} # TODO add after joint flow implementation
end

model(c::Component) = c.model
name(c::Component) = c.name
behaviors(c::Component) = c.behaviors
sim(c::AbstractComponent) = sim((model(c)))

# build behavior from behavior data and component
# and add it to component behaviors
function _addbehavior!(c::Component, b::AbstractBehavior)
    push!(c.behaviors, b)
end

"""
    Component(name::String, model::AbstractModelData, behaviors::Vector{AbstractBehaviorData})
Component constructor. Return a Component with name `name`, based on model `model` and bearing behaviors `behaviors`.
"""
function Component(name::String, model::AbstractModelData, behaviors::AbstractVector)
    
    c = Component(
        name, 
        build(model, name),
        Vector{AbstractBehavior{AffExpr}}(undef,0),
    )

    # some behaviors must be applied before others
    # e.g. capacity behavior must come before overnight cost behavior
    # because overnight cost is based on capacity
    vbehaviordata = _sortbehaviordata(behaviors)

    for b in vbehaviordata
        # build behavior from behavior data
        # then append it to c.behaviors
        _buildaddbehavior!(c, b)
    end

    _apply_constraints!(c)

    return c
end

# fallback for buildbehavior: build the behavior according the the model, not the component
buildbehavior(c::Component, b::AbstractBehaviorData) = buildbehavior(model(c), name(c), b)

# build the behavior
# append it to the behaviors vector of the component
function _buildaddbehavior!(c::Component, b::AbstractBehaviorData)

    bm = buildbehavior(c, b)

    _addbehavior!(c, bm)

end

# apply the constraints to a component
# constraints are from:
#  * the model
#  * the behaviors
function _apply_constraints!(c::Component{AffExpr})

    # model constraints
    _apply_constraints!(model(c))

    #  behaviors constraints
    for b in behaviors(c)
        _apply_constraints!(c, b)
    end

end

# display component info
function Base.show(io::IO, c::Component)
    bs = isempty(behaviors(c)) ? "" : " (" * join([behaviorname(b) for b in behaviors(c)], ", ") * ")"
    print(
        io, 
        "Component \"$(name(c))\" based on $(modelname(model(c))) with $(length(behaviors(c))) behavior(s)$bs"
    )
end
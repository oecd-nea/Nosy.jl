"""
Linked joint flows.

A linked joint flow is a flow which expression is defined or constrained by an affine expression of another flow.
"""

struct LinkedJointFlow{C<:AbstractCarrier,F<:Function,M<:Function} <: AbstractJointFlowData
    name::String
    carrier::C
    sense::Symbol # sense of the joint flow
    baseflows::Vector{String} # names of the existing flow in the component
    f::F # affine function such that joint flow = f(target flow)
    modifier::M # modifier applied to both flows (existing in component and joint)
    mustconnect::Bool
end

"""
    LinkedJointFlow(name::String, carrier::AbstractCarrier, sense::Symbol, baseflows, f::Function; modifier::Function=defaultmodifier, mustconnect::Bool=true)

Return a `LinkedJointFlow` with the following characteristics:
  * `sense`: sense of the joint flow
  * `baseflows`: name or names of the target component flows used to evaluate the joint flow. Must be a string or an iterable of strings.
  * `f`: affine function that calculates the joint flow from `baseflows`, e.g. `x -> x[1] + 2 * x[2]`.
  * `modifier`: modifier applied before `f` to both flows
"""
function LinkedJointFlow(name::String, carrier::AbstractCarrier, sense::Symbol, baseflows, f::Function; modifier::Function=defaultmodifier, mustconnect::Bool=true)
    @argcheck sense == :input ||sense == :output "sense must be equal to :input or :output"
    if baseflows isa String
        bf = [baseflows]
    else 
        bf = collect(baseflows)
    end
    LinkedJointFlow(name, carrier, sense, bf, f, modifier, mustconnect)
end

struct LinkedJointFlowModel{T<:VAL,C,F,M} <: AbstractJointFlow{T}
    data::LinkedJointFlow{C,F,M}
    flow::Stepwise{T}
end

# return a LinkedJointFlowBehavior
function buildjointflow(c::Component, j::LinkedJointFlow)
    vs0 = [j.modifier(getport(c, bf)) for bf in j.baseflows] # vector of modified base flows
    m = first(vs0).mesh
    default_modifier = remesh(defaultmodifier(j.carrier), m)
    joint_modifier = remesh(j.modifier(j.carrier), m)
    sj = Stepwise(j.f(vs0) .* default_modifier ./ joint_modifier, m)
    return LinkedJointFlowModel(j, sj)
end

# add the linked joint flow to the component port structure
function _addbehavior!(c::Component, j::LinkedJointFlowModel)
    p = Port(j.data.carrier, j.flow, !mustconnect(j))
    if j.data.sense == :input
        addinput!(portstructure(c), j.data.name, name(c), p)
    elseif j.data.sense == :output
        addoutput!(portstructure(c), j.data.name, name(c), p)
    end
    push!(c.jointflows, j)
end

name(j::LinkedJointFlowModel) = j.data.name
jointflowname(::LinkedJointFlowModel) = "fixed"
mustconnect(j::LinkedJointFlowModel) = j.data.mustconnect

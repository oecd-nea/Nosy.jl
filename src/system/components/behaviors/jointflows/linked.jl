"""
Linked joint flows.

A linked joint flow is a flow which expression is defined or constrained by an affine expression of another flow.
"""

struct LinkedJointFlow{C<:AbstractCarrier,F<:Function,M<:Function} <: AbstractJointFlowData
    name::String
    carrier::C
    sense::Symbol # sense of the joint flow
    baseflow::String # name of the existing flow in the component
    f::F # affine function such that joint flow = f(target flow)
    modifier::M # modifier applied to both flows (existing in component and joint)
end

"""
    LinkedJointFlow(sense::Symbol, baseflow::String, f::Function; modifier::Function=defaultmodifier)
Return a LinkedJointFlow with following characteristics:
  * `sense`: sense of the joint flow
  * `baseflow`: name of the flow of the target component to evaluate the joint flow from
  * `f`: affine function to calculate the joint flow in function of the `baseflow`
  * `modifier`: modifier applied before `f` to both flows
"""
function LinkedJointFlow(name::String, carrier::AbstractCarrier, sense::Symbol, baseflow::String, f::Function; modifier::Function=defaultmodifier)
    @argcheck sense == :input ||sense == :output "sense must be equal to :input or :output"
    LinkedJointFlow(name, carrier, sense, baseflow, f, modifier)
end

struct LinkedJointFlowModel{T<:VAL,C,F,M} <: AbstractJointFlow{T}
    data::LinkedJointFlow{C,F,M}
    flow::Stepwise{T}
end

# return a LinkedJointFlowBehavior
function buildjointflow(c::Component, j::LinkedJointFlow)
    s0 = j.modifier(getport(c, j.baseflow))
    sj = Stepwise(j.f(s0) .* defaultmodifier(j.carrier) ./ j.modifier(j.carrier), s0.mesh)
    return LinkedJointFlowModel(j, sj)
end

# add the linked joint flow to the component port structure
function _addbehavior!(c::Component, j::LinkedJointFlowModel)
    p = Port(j.data.carrier, j.flow)
    if j.data.sense == :input
        addinput!(portstructure(c), j.data.name, p)
    elseif j.data.sense == :output
        addoutput!(portstructure(c), j.data.name, p)
    end
    push!(c.jointflows, j)
end

name(j::LinkedJointFlowModel) = j.data.name
jointflowname(::LinkedJointFlowModel) = "fixed"
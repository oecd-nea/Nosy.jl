"""
Free joint flows.

A free joint flow is a variable joint flow, not bound to other flows.
"""

struct FreeJointFlow{C<:AbstractCarrier} <: AbstractJointFlowData
    name::String
    carrier::C
    sense::Symbol # sense of the joint flow
    mustconnect::Bool

    @doc """
        FreeJointFlow(name::String, sense::Symbol, carrier::AbstractCarrier; mustconnect::Bool=true)
    Return a FreeJointFlow with name `name`, of sense `sense` of carrier `carrier`.
    """
    function FreeJointFlow(name::String, carrier::AbstractCarrier, sense::Symbol; mustconnect::Bool=true)
        @argcheck sense == :input ||sense == :output "sense must be equal to :input or :output"
        new{typeof(carrier)}(name, carrier, sense, mustconnect)
    end
end



struct FreeJointFlowModel{T<:VAL,C} <: AbstractJointFlow{T}
    data::FreeJointFlow{C}
    flow::Stepwise{T}
end

# return a FreeJointFlowBehavior
function buildjointflow(c::Component, j::FreeJointFlow)
    f = Stepwise(sim(c), lb=0., ub=Inf64, binary=false, integer=false, basename=name(c) * "_" * j.name * "_" * modifiername(_defaultmodifier(carrierstyle(j.carrier))))
    return FreeJointFlowModel(j, f)
end

# add the free joint flow to the component port structure
function _addbehavior!(c::Component, j::FreeJointFlowModel)
    p = Port(j.data.carrier, j.flow, !mustconnect(j))
    if j.data.sense == :input
        addinput!(portstructure(c), j.data.name, name(c), p)
    elseif j.data.sense == :output
        addoutput!(portstructure(c), j.data.name, name(c), p)
    end
    push!(c.jointflows, j)
end

name(j::FreeJointFlowModel) = j.data.name
jointflowname(::FreeJointFlowModel) = "free"
mustconnect(j::FreeJointFlowModel) = j.data.mustconnect
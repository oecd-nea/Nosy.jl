"""
Fixed joint flows.

A fixed joint flow is a joint flow determined by an exogenous time series.
"""

struct FixedJointFlow{C<:AbstractCarrier} <: AbstractJointFlowData
    name::String
    carrier::C
    sense::Symbol # sense of the joint flow
    series::Stepwise{Float64}
    mustconnect::Bool

    @doc """
        FixedJointFlow(name::String, carrier::AbstractCarrier, sense::Symbol, series; mustconnect::Bool=true)

    Return a `FixedJointFlow` with name `name`, sense `sense`, carrier `carrier`, and flow time series or scalar `series`.
    The series uses the carrier simulation mesh and is projected to the component mesh when the component is built.
    """
    function FixedJointFlow(name::String, carrier::AbstractCarrier, sense::Symbol, series; mustconnect::Bool=true)
        @argcheck sense == :input || sense == :output "sense must be equal to :input or :output"
        new{typeof(carrier)}(name, carrier, sense, Stepwise(series, sim(carrier).mesh), mustconnect)
    end  
end



struct FixedJointFlowModel{T<:VAL,C} <: AbstractJointFlow{T}
    data::FixedJointFlow{C}
    flow::Stepwise{T}
end

# return a FixedJointFlowBehavior
function buildjointflow(c::Component, j::FixedJointFlow)
    f = Stepwise(exptype(sim(c)).(remesh(j.series, mesh(c))), mesh(c))
    return FixedJointFlowModel(j, f)
end

# add the fixed joint flow to the component port structure
function _addbehavior!(c::Component, j::FixedJointFlowModel)
    p = Port(j.data.carrier, j.flow, !mustconnect(j))
    if j.data.sense == :input
        addinput!(portstructure(c), j.data.name, name(c), p)
    elseif j.data.sense == :output
        addoutput!(portstructure(c), j.data.name, name(c), p)
    end
    push!(c.jointflows, j)
end

name(j::FixedJointFlowModel) = j.data.name
jointflowname(::FixedJointFlowModel) = "fixed"
mustconnect(j::FixedJointFlowModel) = j.data.mustconnect

"""
Behavior: yearly sum.
"""

using ArgCheck: @argcheck

struct YearlySum{M<:Function} <: AbstractBehaviorData
   pname::String
   val::Float64
   type::Symbol
   modifier::M

    function YearlySum(pname::String, val::Number, type::Symbol, modifier::Function)
        @argcheck val >= 0. "Yearly sum value must be superior or equal to zero"
        @argcheck type in (:equal, :max, :min) "Yearly sum type must be :equal, :max or :min"
        new{typeof(modifier)}(pname, Float64(val), type, modifier)
    end
end

"""
    YearlySum(pname::String, val::Number, type::Symbol; modifier::Function=defaultmodifier)

Return a `YearlySum` behavior, constraining the sum of the flow associated with port `pname` and modifier `modifier` over the year.
If `type` is `:equal`, the sum is constrained to be equal to `val`. 
If `type` is `:max`, the sum is constrained to be less than or equal to `val`.
If `type` is `:min`, the sum is constrained to be greater than or equal to `val`.
"""
function YearlySum(pname::String, val::Number, type::Symbol; modifier::Function=defaultmodifier)
    return YearlySum(pname, val, type, modifier)
end

struct YearlySumBehavior{T,M} <: AbstractRegularBehavior{T}
    data::YearlySum{M}
    val::T
end

buildbehavior(c::Component, b::YearlySum) = YearlySumBehavior(b, exptype(sim(c))(b.val))

function _apply_constraints!(c::Component, b::YearlySumBehavior)
    f = sum(b.data.modifier(getport(c, b.data.pname)))
    if b.data.type == :equal
        @constraint(lowermodel(sim(c)), f == b.val)
    elseif b.data.type == :max
        @constraint(lowermodel(sim(c)), f <= b.val)
    elseif b.data.type == :min
        @constraint(lowermodel(sim(c)), f >= b.val)
    end
end

behaviorname(::YearlySumBehavior) = "yearly sum"
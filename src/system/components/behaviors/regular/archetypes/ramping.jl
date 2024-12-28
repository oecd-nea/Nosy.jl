"""
Ramping behavior.

Defines a max rate for a given ramping sense.
Definition of this component requires a unit size.
This behavior is applied differently according to whether the component also has unit comitment.
"""

using ArgCheck: @argcheck

struct Ramping{M} <: AbstractBehaviorData
    pname::String
    sense::Symbol
    val::Float64
    modifier::M

    function Ramping(pname::String, sense::Symbol, val::Number, modifier::Function)
        @argcheck (sense == :up || sense == :down) "Ramping sense must be :up or :down"
        @argcheck val >= 0. "Ramping value must be superior or equal to zero"
        new{typeof(modifier)}(pname, sense, Float64(val), modifier)
    end
end

"""
    Ramping(pname::String, sense::Symbol, val::Number; modifier::Function=defaultmodifier)
Return a Ramping behavior.
"""
function Ramping(pname::String, sense::Symbol, val::Number; modifier::Function=defaultmodifier)
    return Ramping(pname, sense, val, modifier)
end

struct RampingBehavior{T} <: AbstractRegularBehavior{T}
    data::Ramping
end

buildbehavior(::Component, b::Ramping) = RampingBehavior{AffExpr}(b)

RampingBehavior(d::Ramping) = RampingBehavior{Float64}(d)

# if component has uc associated with same port, apply ramping to this port
# if component has uc but not associated with same port, throw error
# if component has no uc, check if it has a number of units defined
# if the component has a number of units defined, apply unit-wise ramping
# if the component has no number of units, apply ramping to the model as a whole
function _apply_constraints!(c::Component, b::RampingBehavior)
    vuc = getbehaviors(c, AbstractUnitCommitmentBehavior)
    # component has uc
    if !isempty(vuc)
        for uc in vuc
            # if one of the uc has same port
            if uc.data.pname == b.data.pname
                _apply_constraints_ramping_uc!(c, b, uc)
                return nothing
            end 
        end

        # if none of the uc is associated with ramping target port
        throw(AssertionError("Unit commitment of $(name(c)) not compatible with ramping: different port is targeted"))
    end
    
    # component has no uc
    # if unit size is defined (in a capacity behavior), apply a version of ramping that considers unit size
    # if unit size is not defined, consider only one unit is there ("model" ramping)
    if isnothing(nbunits(c))
        _apply_constraints_ramping_model!(c, b)
    else
        _apply_constraints_ramping_unitsize!(c, b)
    end
end

# apply the ramping constraint to the matching single unit commitment behavior
function _apply_constraints_ramping_uc!(::Component, ::RampingBehavior, ::SingleUnitCommitmentBehavior)
    error("not implemented")
end

# apply the ramping constraint to the matching fleet unit commitment behavior
function _apply_constraints_ramping_uc!(c::Component, b::RampingBehavior, uc::FleetUnitCommitmentBehavior)
    var = _var(uc) # variable flow from uc, in the uc modifier
    car = getport(c, b.data.pname).carrier
    diff = (shift(var,1) - var) .* b.data.modifier(car) ./ uc.modifier(car) # conversion of diff to ramping carrier
    maxramp = uc.state .* weight(sim(c).mesh) * b.data.val
    if b.data.sense == :up
        @constraint(sim(c).model, 
            diff.data <= uc.state .* weight(sim(c).mesh) * b.data.val
        )
    elseif b.data.sense == :down
        @constraint(sim(c).model,
            diff.data >= - shift(uc.state,1) .* weight(sim(c).mesh) * b.data.val
        )
    else
        throw(AssertionError("this portion of code should never be reached"))
    end
end

# apply the ramping constraint to the model, considering unit size
function _apply_constraints_ramping_unitsize!(c::Component, b::RampingBehavior)
    diff = shift(b.data.modifier(getport(c, b.data.pname)),1) - b.data.modifier(getport(c, b.data.pname))
    maxramp = nbunits(c) .* weight(sim(c).mesh) * b.data.val
    if b.data.sense == :up
        @constraint(sim(c).model, 
            diff.data <= maxramp
        )
    elseif b.data.sense == :down
        @constraint(sim(c).model,
            diff.data >= - maxramp
        )
    end
end

# apply the ramping constraint to the model, considering no uc or unit size
function _apply_constraints_ramping_model!(c::Component, b::RampingBehavior)
    f = b.data.modifier(getport(c, b.data.pname))
    if b.data.sense == :up
        @constraint(sim(c).model, 
            (shift(f,1) - f).data <= weight(sim(c).mesh) * b.data.val
        )
    elseif b.data.sense == :down
        @constraint(sim(c).model, 
            (shift(f,1) - f).data >= - weight(sim(c).mesh) * b.data.val
        )
    end
end

function behaviorname(b::RampingBehavior)
    if b.data.sense == :up
        return "ramp up"
    else
        return "ramp down"
    end
end

# display behavior info
function Base.show(io::IO, b::RampingBehavior)
    print(
        io, 
        "Behavior \"$(behaviorname(b))\""
    )
  end
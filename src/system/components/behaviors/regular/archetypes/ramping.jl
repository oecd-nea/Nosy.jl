"""
Ramping behavior.

Defines a max rate for a given ramping sense.
Definition of this component requires a unit size.
This behavior is applied differently according to whether the component also has unit commitment.
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

Return a `Ramping` behavior that constrains the ramp rate of port `pname`.
`sense` must be `:up` or `:down`, and `val` is the maximum rate in the modified carrier unit per hour.
"""
function Ramping(pname::String, sense::Symbol, val::Number; modifier::Function=defaultmodifier)
    return Ramping(pname, sense, val, modifier)
end

struct RampingBehavior{T} <: AbstractRegularBehavior{T}
    data::Ramping
end

buildbehavior(c::Component, b::Ramping) = RampingBehavior{exptype(sim(c))}(b)

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

# apply the ramping constraint to the matching fleet unit commitment behavior
function _apply_constraints_ramping_uc!(c::Component, b::RampingBehavior, uc::FleetUnitCommitmentBehavior)
    var = _var(uc) # variable flow from uc, in the uc modifier
    car = getport(c, b.data.pname).carrier
    diff = (shift(var,1) - var) .* b.data.modifier(car) ./ uc.modifier(car) # conversion of diff to ramping carrier
    if b.data.sense == :up
        @constraint(lowermodel(sim(c)), 
            diff.data <= uc.state .* weight(mesh(c)) * b.data.val
        )
    elseif b.data.sense == :down
        @constraint(lowermodel(sim(c)),
            diff.data >= - shift(uc.state,1) .* weight(mesh(c)) * b.data.val
        )
    else
        throw(AssertionError("this portion of code should never be reached"))
    end
end

# apply the ramping constraint to the model, considering unit size
function _apply_constraints_ramping_unitsize!(c::Component, b::RampingBehavior)
    diff = shift(b.data.modifier(getport(c, b.data.pname)),1) - b.data.modifier(getport(c, b.data.pname))
    maxramp = nbunits(c) .* weight(mesh(c)) * b.data.val
    if b.data.sense == :up
        @constraint(lowermodel(sim(c)), 
            diff.data <= maxramp
        )
    elseif b.data.sense == :down
        @constraint(lowermodel(sim(c)),
            diff.data >= - maxramp
        )
    end
end

# apply the ramping constraint to the model, considering no uc or unit size
function _apply_constraints_ramping_model!(c::Component, b::RampingBehavior)
    f = b.data.modifier(getport(c, b.data.pname))
    if b.data.sense == :up
        @constraint(lowermodel(sim(c)), 
            (shift(f,1) - f).data <= weight(mesh(c)) * b.data.val
        )
    elseif b.data.sense == :down
        @constraint(lowermodel(sim(c)), 
            (shift(f,1) - f).data >= - weight(mesh(c)) * b.data.val
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

# helper function for other behaviors to query ramping behavior
# returns RampingBehavior if found, nothing otherwise (currently used by ReserveUp, maybe used by ReserveDown too)
function getrampingbehavior(c::Component, pname::String, sense::Symbol)
    for b in getbehaviors(c, RampingBehavior)
        if b.data.pname == pname && b.data.sense == sense
            return b
        end
    end
    return nothing
end
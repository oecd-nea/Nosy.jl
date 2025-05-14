"""
Duration behavior.

Used for storage-like models, to link together the flow capacity (input, output etc.) and the level.
"""

struct Duration <: AbstractBehaviorData
    hours::Float64
    inputpname::String
    outputpname::String
    levelpname::String

    @doc"""
        Duration(hours::Number; inputpname::String="input", outputpname::String="output", levelpname::String="level")
    Return a Duration behavior data, linking model capacities for ports `flowpname` and `levelpname` by the duration `hours`.
    """
    Duration(hours::Number; inputpname::String="input", outputpname::String="output", levelpname::String="level") = new(Float64(hours), inputpname, outputpname, levelpname)
end


struct DurationBehavior{T} <: AbstractRegularBehavior{T}
    data::Duration
    capacitypname::String
    _type::Type{T} # to not make a specific constructor
end


function buildbehavior(c::Component, b::Duration)
    @assert hasport(c, b.inputpname) "Component $(name(c)) does not have port named $(b.inputpname)"
    @assert hasport(c, b.outputpname) "Component $(name(c)) does not have port named $(b.outputpname)"
    @assert hasport(c, b.levelpname) "Component $(name(c)) does not have port named $(b.levelpname)"

    # check which port is already linked to a capacity
    _hasicap = hascapacitybehavior(c, b.inputpname)
    _hasocap = hascapacitybehavior(c, b.outputpname)
    _haslcap = hascapacitybehavior(c, b.levelpname)

    @assert (_hasicap + _hasocap + _haslcap) == 1 "There should be exactly one port among $(_inputpname(b)), $(_outputpname(b)) and $(_levelpname(b)) associated with capacity."
    capacitypname = _hasicap ? b.inputpname : (_hasocap ? b.outputpname : b.levelpname)

        
    return DurationBehavior(b, capacitypname, exptype(sim(c)))
end

_inputpname(b::DurationBehavior) = b.data.inputpname
_outputpname(b::DurationBehavior) = b.data.outputpname
_levelpname(b::DurationBehavior) = b.data.levelpname
_hours(b::DurationBehavior) = b.data.hours
_capacitypname(b::DurationBehavior) = b.capacitypname

# the Duration behavior is applied after the capacity behaviors
function _apply_constraints!(c::Component, b::DurationBehavior)
    if _capacitypname(b) == _inputpname(b)
        cap = getcapacitybehavior(c, _inputpname(b))
        _bmod = _modifier(cap)
        _bcap = _capacity(cap)
        # output capacity
        @constraint(lowermodel(sim(c)), 
            _bmod(getport(c, _outputpname(b))).data .<= _bcap
        )              
        
        # level capacity
        @constraint(lowermodel(sim(c)), 
            _bmod(getport(c, _levelpname(b))).data .<= _bcap * _hours(b)
        )        
    elseif _capacitypname(b) == _outputpname(b)
         cap = getcapacitybehavior(c, _inputpname(b))
        _bmod = _modifier(cap)
        _bcap = _capacity(cap)

        # input capacity
        @constraint(lowermodel(sim(c)), 
            _bmod(getport(c, _inputpname(b))).data .<= _bcap
        )              
        # level capacity
        @constraint(lowermodel(sim(c)), 
            _bmod(getport(c, _levelpname(b))).data .<= _bcap * _hours(b)
        )      
    elseif _capacitypname(b) == _levelpname(b)
        cap = getcapacitybehavior(c, _levelpname(b))
        _bmod = _modifier(cap)
        _bcap = _capacity(cap)
        # input capacity
        @constraint(lowermodel(sim(c)), 
            _bmod(getport(c, _inputpname(b))).data .<= _bcap / _hours(b)
        )  

        # output capacity
        @constraint(lowermodel(sim(c)), 
            _bmod(getport(c, _outputpname(b))).data .<= _bcap / _hours(b)
        )  
    else
        throw(AssertionError("This case should never happen"))
    end
end

behaviorname(::DurationBehavior) = "fixed storage duration"
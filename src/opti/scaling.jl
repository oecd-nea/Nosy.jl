import MathOptInterface as MOI

const _SCALABLE_FUNCTION = MOI.ScalarAffineFunction
const _SCALABLE_SET =
    Union{MOI.LessThan,MOI.GreaterThan,MOI.EqualTo,MOI.Interval}
const _SCALABLE_SET_OF{T} =
    Union{MOI.LessThan{T},MOI.GreaterThan{T},MOI.EqualTo{T},MOI.Interval{T}}

function _update_minmax((minabs, maxabs)::Tuple{Float64,Float64}, value)
    absvalue = abs(Float64(value))
    if iszero(absvalue) || !isfinite(absvalue)
        return minabs, maxabs
    end
    return min(minabs, absvalue), max(maxabs, absvalue)
end

function _coefficient_minmax(func::MOI.ScalarAffineFunction)
    minabs = Inf
    maxabs = 0.0
    for term in func.terms
        minabs, maxabs = _update_minmax((minabs, maxabs), term.coefficient)
    end
    return _update_minmax((minabs, maxabs), func.constant)
end

_bound_minmax(minmax, set::MOI.LessThan) =
    _update_minmax(minmax, set.upper)
_bound_minmax(minmax, set::MOI.GreaterThan) =
    _update_minmax(minmax, set.lower)
_bound_minmax(minmax, set::MOI.EqualTo) =
    _update_minmax(minmax, set.value)
function _bound_minmax(minmax, set::MOI.Interval)
    minmax = _update_minmax(minmax, set.lower)
    return _update_minmax(minmax, set.upper)
end

function _term_minmax(func::MOI.ScalarAffineFunction, set::_SCALABLE_SET)
    return _bound_minmax(_coefficient_minmax(func), set)
end

function _scale_factor(
    func::_SCALABLE_FUNCTION,
    set::_SCALABLE_SET,
    target::Float64,
)
    minabs, maxabs = _term_minmax(func, set)
    if isinf(minabs) || iszero(maxabs)
        return 1.0
    end
    return target / (sqrt(minabs) * sqrt(maxabs))
end

function _scale_function(func::MOI.ScalarAffineFunction{T}, scale) where {T}
    return MOI.ScalarAffineFunction(
        MOI.ScalarAffineTerm{T}[
            MOI.ScalarAffineTerm(scale * term.coefficient, term.variable)
            for term in func.terms
        ],
        scale * func.constant,
    )
end

_scale_set(set::MOI.LessThan, scale) = MOI.LessThan(scale * set.upper)
_scale_set(set::MOI.GreaterThan, scale) = MOI.GreaterThan(scale * set.lower)
_scale_set(set::MOI.EqualTo, scale) = MOI.EqualTo(scale * set.value)
function _scale_set(set::MOI.Interval, scale)
    return MOI.Interval(scale * set.lower, scale * set.upper)
end

_unscale_function(func::_SCALABLE_FUNCTION, scale) =
    _scale_function(func, inv(scale))
_unscale_set(set::_SCALABLE_SET, scale) = _scale_set(set, inv(scale))

function _scale_change(change::MOI.ScalarConstantChange, scale)
    return MOI.ScalarConstantChange(scale * change.new_constant)
end

function _scale_change(change::MOI.ScalarCoefficientChange, scale)
    return MOI.ScalarCoefficientChange(
        change.variable,
        scale * change.new_coefficient,
    )
end

_scale_change(change::MOI.AbstractFunctionModification, scale) = change

_scale_value(value, scale) = scale * value
_scale_value(::Nothing, scale) = nothing
_unscale_value(value, scale) = value / scale
_unscale_value(::Nothing, scale) = nothing

"""
    ScaledConstraintBridge{Target,T,S}

Scale one scalar affine constraint row before it reaches the optimizer.
"""
mutable struct ScaledConstraintBridge{Target,T,S<:_SCALABLE_SET} <:
               MOI.Bridges.Constraint.AbstractBridge
    constraint::MOI.ConstraintIndex{MOI.ScalarAffineFunction{T},S}
    scale::T
end

function _typed_scale(
    ::Type{T},
    func::MOI.ScalarAffineFunction,
    set::_SCALABLE_SET,
    target::Float64,
) where {T}
    return T(_scale_factor(func, set, target))
end

function MOI.supports_constraint(
    ::Type{<:ScaledConstraintBridge{Target,T}},
    ::Type{MOI.ScalarAffineFunction{T}},
    ::Type{S},
) where {Target,T,S<:_SCALABLE_SET_OF{T}}
    return true
end

function MOI.Bridges.Constraint.concrete_bridge_type(
    ::Type{<:ScaledConstraintBridge{Target,T}},
    ::Type{MOI.ScalarAffineFunction{T}},
    ::Type{S},
) where {Target,T,S<:_SCALABLE_SET_OF{T}}
    return ScaledConstraintBridge{Target,T,S}
end

function MOI.Bridges.Constraint.bridge_constraint(
    ::Type{ScaledConstraintBridge{Target,T,S}},
    model::MOI.ModelLike,
    func::MOI.ScalarAffineFunction{T},
    set::S,
) where {Target,T,S<:_SCALABLE_SET}
    scale = _typed_scale(T, func, set, Float64(Target))
    constraint = MOI.add_constraint(
        model,
        _scale_function(func, scale),
        _scale_set(set, scale),
    )
    return ScaledConstraintBridge{Target,T,S}(constraint, scale)
end

function MOI.Bridges.added_constrained_variable_types(
    ::Type{<:ScaledConstraintBridge},
)
    return Tuple{Type}[]
end

function MOI.Bridges.added_constraint_types(
    ::Type{<:ScaledConstraintBridge{Target,T,S}},
) where {Target,T,S}
    return Tuple{Type,Type}[(MOI.ScalarAffineFunction{T}, S)]
end

function MOI.get(
    bridge::ScaledConstraintBridge{Target,T,S},
    ::MOI.NumberOfConstraints{MOI.ScalarAffineFunction{T},S},
)::Int64 where {Target,T,S}
    return 1
end

function MOI.get(
    bridge::ScaledConstraintBridge{Target,T,S},
    ::MOI.ListOfConstraintIndices{MOI.ScalarAffineFunction{T},S},
) where {Target,T,S}
    return [bridge.constraint]
end

function MOI.get(::ScaledConstraintBridge, ::MOI.NumberOfVariables)::Int64
    return 0
end

function MOI.get(::ScaledConstraintBridge, ::MOI.ListOfVariableIndices)
    return MOI.VariableIndex[]
end

function MOI.delete(model::MOI.ModelLike, bridge::ScaledConstraintBridge)
    MOI.delete(model, bridge.constraint)
    return
end

function MOI.get(
    model::MOI.ModelLike,
    ::MOI.ConstraintFunction,
    bridge::ScaledConstraintBridge,
)
    func = MOI.get(model, MOI.ConstraintFunction(), bridge.constraint)
    return _unscale_function(func, bridge.scale)
end

function MOI.get(
    model::MOI.ModelLike,
    ::MOI.ConstraintSet,
    bridge::ScaledConstraintBridge,
)
    set = MOI.get(model, MOI.ConstraintSet(), bridge.constraint)
    return _unscale_set(set, bridge.scale)
end

function MOI.modify(
    model::MOI.ModelLike,
    bridge::ScaledConstraintBridge,
    change::MOI.AbstractFunctionModification,
)
    MOI.modify(model, bridge.constraint, _scale_change(change, bridge.scale))
    return
end

function MOI.set(
    model::MOI.ModelLike,
    ::MOI.ConstraintFunction,
    bridge::ScaledConstraintBridge{Target,T,S},
    func::MOI.ScalarAffineFunction{T},
) where {Target,T,S}
    set = MOI.get(model, MOI.ConstraintSet(), bridge)
    bridge.scale = _typed_scale(T, func, set, Float64(Target))
    MOI.set(
        model,
        MOI.ConstraintFunction(),
        bridge.constraint,
        _scale_function(func, bridge.scale),
    )
    MOI.set(
        model,
        MOI.ConstraintSet(),
        bridge.constraint,
        _scale_set(set, bridge.scale),
    )
    return
end

function MOI.set(
    model::MOI.ModelLike,
    ::MOI.ConstraintSet,
    bridge::ScaledConstraintBridge,
    set::_SCALABLE_SET,
)
    MOI.set(
        model,
        MOI.ConstraintSet(),
        bridge.constraint,
        _scale_set(set, bridge.scale),
    )
    return
end

function MOI.supports(
    model::MOI.ModelLike,
    attr::Union{MOI.ConstraintPrimalStart,MOI.ConstraintDualStart},
    ::Type{<:ScaledConstraintBridge{Target,T,S}},
) where {Target,T,S}
    return MOI.supports(
        model,
        attr,
        MOI.ConstraintIndex{MOI.ScalarAffineFunction{T},S},
    )
end

function MOI.get(
    model::MOI.ModelLike,
    attr::Union{MOI.ConstraintPrimal,MOI.ConstraintPrimalStart},
    bridge::ScaledConstraintBridge,
)
    return _unscale_value(MOI.get(model, attr, bridge.constraint), bridge.scale)
end

function MOI.get(
    model::MOI.ModelLike,
    attr::Union{MOI.ConstraintDual,MOI.ConstraintDualStart},
    bridge::ScaledConstraintBridge,
)
    return _scale_value(MOI.get(model, attr, bridge.constraint), bridge.scale)
end

function MOI.set(
    model::MOI.ModelLike,
    attr::MOI.ConstraintPrimalStart,
    bridge::ScaledConstraintBridge,
    value,
)
    MOI.set(model, attr, bridge.constraint, _scale_value(value, bridge.scale))
    return
end

function MOI.set(
    model::MOI.ModelLike,
    attr::MOI.ConstraintDualStart,
    bridge::ScaledConstraintBridge,
    value,
)
    MOI.set(model, attr, bridge.constraint, _unscale_value(value, bridge.scale))
    return
end

"""
    ScaledOptimizer(optimizer_constructor; target = 1e5)

Return an optimizer factory that scales scalar affine constraints before they
are passed to `optimizer_constructor`.

Scalar affine constraints in `LessThan`, `GreaterThan`, `EqualTo`, and
`Interval` sets are scaled. The geometric mean of the smallest and largest
finite nonzero absolute values among the left-hand-side coefficients and
right-hand-side bounds is scaled to `target`. Variable bounds, integrality
constraints, vector constraints, quadratic constraints, and nonlinear
constraints are passed through unchanged.
"""
function ScaledOptimizer(optimizer_constructor; target::Real = 1e5)
    return () -> ScaledOptimizer(MOI.instantiate(optimizer_constructor); target)
end

function ScaledOptimizer(inner::MOI.ModelLike; target::Real = 1e5)
    target > 0 || throw(ArgumentError("constraint scaling target must be positive"))
    bridge_type = ScaledConstraintBridge{Float64(target),Float64}
    return MOI.Bridges.Constraint.SingleBridgeOptimizer{bridge_type}(inner)
end

function MOI.get(
    model::MOI.Bridges.Constraint.SingleBridgeOptimizer{BT},
    attr::MOI.SolverName,
) where {BT<:ScaledConstraintBridge}
    return "ScaledOptimizer($(MOI.get(model.model, attr)))"
end

"""
    scaled_model(optimizer_constructor; target = 1e5, kwargs...)

Create a `JuMP.Model` whose optimizer is wrapped in [`ScaledOptimizer`](@ref).
Constraints added with JuMP's `@constraint` macro are therefore scaled before
they reach the solver.
"""
function scaled_model(optimizer_constructor; target::Real = 1e5, kwargs...)
    return JuMP.Model(ScaledOptimizer(optimizer_constructor; target); kwargs...)
end

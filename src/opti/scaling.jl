import MathOptInterface as MOI

"""
    ScaledOptimizer(optimizer_constructor; target = 1e5)

Return an optimizer factory that wraps `optimizer_constructor` in a constraint
scaling layer.

Scalar affine constraints in `LessThan`, `GreaterThan`, `EqualTo`, and
`Interval` sets are scaled before they are passed to the wrapped optimizer. The
geometric mean of the smallest and largest finite nonzero absolute values among
the left-hand-side coefficients and right-hand-side bounds is scaled to `target`.
Variable bounds, integrality constraints, vector constraints, quadratic
constraints, and nonlinear constraints are passed through unchanged.
"""
mutable struct ScaledOptimizer{O<:MOI.ModelLike} <: MOI.AbstractOptimizer
    inner::O
    target::Float64
    scales::Dict{Any,Any}
end

function ScaledOptimizer(optimizer_constructor; target::Real = 1e5)
    return () -> ScaledOptimizer(MOI.instantiate(optimizer_constructor); target)
end

function ScaledOptimizer(inner::MOI.ModelLike; target::Real = 1e5)
    target > 0 || throw(ArgumentError("constraint scaling target must be positive"))
    return ScaledOptimizer(inner, Float64(target), Dict{Any,Any}())
end

_inner(model::ScaledOptimizer) = model.inner

const _SCALABLE_FUNCTION = MOI.ScalarAffineFunction
const _SCALABLE_SET =
    Union{MOI.LessThan,MOI.GreaterThan,MOI.EqualTo,MOI.Interval}

_scale(model::ScaledOptimizer, index::MOI.ConstraintIndex) =
    get(model.scales, index, 1.0)

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

function _scale_function(
    func::MOI.ScalarAffineFunction{T},
    scale,
) where {T}
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

function MOI.add_variable(model::ScaledOptimizer)
    return MOI.add_variable(_inner(model))
end

function MOI.add_variables(model::ScaledOptimizer, n::Integer)
    return MOI.add_variables(_inner(model), n)
end

function MOI.add_constrained_variable(
    model::ScaledOptimizer,
    set::MOI.AbstractScalarSet,
)
    return MOI.add_constrained_variable(_inner(model), set)
end

function MOI.add_constrained_variables(
    model::ScaledOptimizer,
    set::MOI.AbstractVectorSet,
)
    return MOI.add_constrained_variables(_inner(model), set)
end

function MOI.add_constraint(
    model::ScaledOptimizer,
    func::_SCALABLE_FUNCTION,
    set::_SCALABLE_SET,
)
    scale = _scale_factor(func, set, model.target)
    index = MOI.add_constraint(
        _inner(model),
        _scale_function(func, scale),
        _scale_set(set, scale),
    )
    model.scales[index] = scale
    return index
end

function MOI.add_constraint(
    model::ScaledOptimizer,
    func::MOI.AbstractFunction,
    set::MOI.AbstractSet,
)
    return MOI.add_constraint(_inner(model), func, set)
end

function MOI.add_constraint(
    model::ScaledOptimizer,
    func::MOI.VariableIndex,
    set::MOI.AbstractSet,
)
    return MOI.add_constraint(_inner(model), func, set)
end

MOI.optimize!(model::ScaledOptimizer) = MOI.optimize!(_inner(model))
MOI.compute_conflict!(model::ScaledOptimizer) = MOI.compute_conflict!(_inner(model))

function MOI.empty!(model::ScaledOptimizer)
    empty!(model.scales)
    return MOI.empty!(_inner(model))
end

MOI.is_empty(model::ScaledOptimizer) =
    isempty(model.scales) && MOI.is_empty(_inner(model))

MOI.is_valid(model::ScaledOptimizer, index::MOI.Index) =
    MOI.is_valid(_inner(model), index)

function MOI.delete(model::ScaledOptimizer, index::MOI.ConstraintIndex)
    delete!(model.scales, index)
    return MOI.delete(_inner(model), index)
end

MOI.delete(model::ScaledOptimizer, index::MOI.VariableIndex) =
    MOI.delete(_inner(model), index)

MOI.delete(model::ScaledOptimizer, indices::Vector{MOI.VariableIndex}) =
    MOI.delete(_inner(model), indices)

function MOI.delete(model::ScaledOptimizer, indices::Vector{<:MOI.ConstraintIndex})
    foreach(index -> delete!(model.scales, index), indices)
    return MOI.delete(_inner(model), indices)
end

function MOI.modify(
    model::ScaledOptimizer,
    index::MOI.ConstraintIndex,
    change::MOI.AbstractFunctionModification,
)
    return MOI.modify(
        _inner(model),
        index,
        _scale_change(change, _scale(model, index)),
    )
end

function MOI.modify(
    model::ScaledOptimizer,
    attr::MOI.ObjectiveFunction,
    change::MOI.AbstractFunctionModification,
)
    return MOI.modify(_inner(model), attr, change)
end

function MOI.set(
    model::ScaledOptimizer,
    ::MOI.ConstraintSet,
    index::MOI.ConstraintIndex{F,S},
    set::S,
) where {F<:_SCALABLE_FUNCTION,S<:_SCALABLE_SET}
    return MOI.set(
        _inner(model),
        MOI.ConstraintSet(),
        index,
        _scale_set(set, _scale(model, index)),
    )
end

function MOI.set(
    model::ScaledOptimizer,
    ::MOI.ConstraintSet,
    index::MOI.ConstraintIndex{F,S},
    set::S,
) where {F<:MOI.AbstractFunction,S<:MOI.AbstractSet}
    return MOI.set(_inner(model), MOI.ConstraintSet(), index, set)
end

function MOI.set(
    model::ScaledOptimizer,
    ::MOI.ConstraintFunction,
    index::MOI.ConstraintIndex{F,S},
    func::F,
) where {F<:_SCALABLE_FUNCTION,S<:_SCALABLE_SET}
    old_scale = _scale(model, index)
    original_set = _unscale_set(
        MOI.get(_inner(model), MOI.ConstraintSet(), index),
        old_scale,
    )
    new_scale = _scale_factor(func, original_set, model.target)
    MOI.set(
        _inner(model),
        MOI.ConstraintFunction(),
        index,
        _scale_function(func, new_scale),
    )
    MOI.set(
        _inner(model),
        MOI.ConstraintSet(),
        index,
        _scale_set(original_set, new_scale),
    )
    model.scales[index] = new_scale
    return
end

function MOI.set(
    model::ScaledOptimizer,
    ::MOI.ConstraintFunction,
    index::MOI.ConstraintIndex{F},
    func::F,
) where {F<:MOI.AbstractFunction}
    return MOI.set(_inner(model), MOI.ConstraintFunction(), index, func)
end

function MOI.get(
    model::ScaledOptimizer,
    ::MOI.ConstraintFunction,
    index::MOI.ConstraintIndex{F,S},
) where {F<:_SCALABLE_FUNCTION,S<:_SCALABLE_SET}
    func = MOI.get(_inner(model), MOI.ConstraintFunction(), index)
    return _unscale_function(func, _scale(model, index))
end

function MOI.get(
    model::ScaledOptimizer,
    ::MOI.CanonicalConstraintFunction,
    index::MOI.ConstraintIndex{F,S},
) where {F<:_SCALABLE_FUNCTION,S<:_SCALABLE_SET}
    func = MOI.get(_inner(model), MOI.CanonicalConstraintFunction(), index)
    return _unscale_function(func, _scale(model, index))
end

function MOI.get(
    model::ScaledOptimizer,
    ::MOI.ConstraintSet,
    index::MOI.ConstraintIndex{F,S},
) where {F<:_SCALABLE_FUNCTION,S<:_SCALABLE_SET}
    set = MOI.get(_inner(model), MOI.ConstraintSet(), index)
    return _unscale_set(set, _scale(model, index))
end

function MOI.get(
    model::ScaledOptimizer,
    attr::MOI.ConstraintPrimal,
    index::MOI.ConstraintIndex{F,S},
) where {F<:_SCALABLE_FUNCTION,S<:_SCALABLE_SET}
    return MOI.get(_inner(model), attr, index) / _scale(model, index)
end

function MOI.get(
    model::ScaledOptimizer,
    attr::MOI.ConstraintDual,
    index::MOI.ConstraintIndex{F,S},
) where {F<:_SCALABLE_FUNCTION,S<:_SCALABLE_SET}
    return _scale(model, index) * MOI.get(_inner(model), attr, index)
end

function MOI.get(
    model::ScaledOptimizer,
    attr::MOI.ConstraintPrimalStart,
    index::MOI.ConstraintIndex{F,S},
) where {F<:_SCALABLE_FUNCTION,S<:_SCALABLE_SET}
    return _unscale_value(MOI.get(_inner(model), attr, index), _scale(model, index))
end

function MOI.get(
    model::ScaledOptimizer,
    attr::MOI.ConstraintDualStart,
    index::MOI.ConstraintIndex{F,S},
) where {F<:_SCALABLE_FUNCTION,S<:_SCALABLE_SET}
    return _scale_value(MOI.get(_inner(model), attr, index), _scale(model, index))
end

function MOI.set(
    model::ScaledOptimizer,
    attr::MOI.ConstraintPrimalStart,
    index::MOI.ConstraintIndex{F,S},
    value,
) where {F<:_SCALABLE_FUNCTION,S<:_SCALABLE_SET}
    return MOI.set(
        _inner(model),
        attr,
        index,
        _scale_value(value, _scale(model, index)),
    )
end

function MOI.set(
    model::ScaledOptimizer,
    attr::MOI.ConstraintDualStart,
    index::MOI.ConstraintIndex{F,S},
    value,
) where {F<:_SCALABLE_FUNCTION,S<:_SCALABLE_SET}
    return MOI.set(
        _inner(model),
        attr,
        index,
        _unscale_value(value, _scale(model, index)),
    )
end

function MOI.set(model::ScaledOptimizer, attr::MOI.AbstractOptimizerAttribute, value)
    return MOI.set(_inner(model), attr, value)
end

function MOI.set(model::ScaledOptimizer, attr::MOI.AbstractModelAttribute, value)
    return MOI.set(_inner(model), attr, value)
end

function MOI.set(
    model::ScaledOptimizer,
    attr::MOI.AbstractVariableAttribute,
    index::MOI.VariableIndex,
    value,
)
    return MOI.set(_inner(model), attr, index, value)
end

function MOI.set(
    model::ScaledOptimizer,
    attr::MOI.AbstractConstraintAttribute,
    index::MOI.ConstraintIndex,
    value,
)
    return MOI.set(_inner(model), attr, index, value)
end

MOI.get(model::ScaledOptimizer, attr::MOI.AbstractOptimizerAttribute) =
    MOI.get(_inner(model), attr)

function MOI.get(model::ScaledOptimizer, attr::MOI.SolverName)
    return "ScaledOptimizer($(MOI.get(_inner(model), attr)))"
end

MOI.get(model::ScaledOptimizer, attr::MOI.AbstractModelAttribute) =
    MOI.get(_inner(model), attr)

function MOI.get(
    model::ScaledOptimizer,
    attr::MOI.AbstractVariableAttribute,
    index::MOI.VariableIndex,
)
    return MOI.get(_inner(model), attr, index)
end

function MOI.get(
    model::ScaledOptimizer,
    attr::MOI.AbstractConstraintAttribute,
    index::MOI.ConstraintIndex,
)
    return MOI.get(_inner(model), attr, index)
end

function MOI.get(model::ScaledOptimizer, index_type::Type{<:MOI.Index}, name::String)
    return MOI.get(_inner(model), index_type, name)
end

MOI.supports(model::ScaledOptimizer, attr::MOI.AbstractOptimizerAttribute) =
    MOI.supports(_inner(model), attr)

MOI.supports(model::ScaledOptimizer, attr::MOI.AbstractModelAttribute) =
    MOI.supports(_inner(model), attr)

function MOI.supports(
    model::ScaledOptimizer,
    attr::MOI.AbstractVariableAttribute,
    index_type::Type{MOI.VariableIndex},
)
    return MOI.supports(_inner(model), attr, index_type)
end

function MOI.supports(
    model::ScaledOptimizer,
    attr::MOI.AbstractConstraintAttribute,
    index_type::Type{<:MOI.ConstraintIndex},
)
    return MOI.supports(_inner(model), attr, index_type)
end

function MOI.supports_constraint(
    model::ScaledOptimizer,
    F::Type{<:MOI.AbstractFunction},
    S::Type{<:MOI.AbstractSet},
)
    return MOI.supports_constraint(_inner(model), F, S)
end

function MOI.supports_add_constrained_variable(
    model::ScaledOptimizer,
    S::Type{<:MOI.AbstractScalarSet},
)
    return MOI.supports_add_constrained_variable(_inner(model), S)
end

function MOI.supports_add_constrained_variables(
    model::ScaledOptimizer,
    S::Type{<:MOI.AbstractVectorSet},
)
    return MOI.supports_add_constrained_variables(_inner(model), S)
end

function MOI.supports_add_constrained_variables(
    model::ScaledOptimizer,
    ::Type{MOI.Reals},
)
    return MOI.supports_add_constrained_variables(_inner(model), MOI.Reals)
end

MOI.supports(model::ScaledOptimizer, sub::MOI.AbstractSubmittable) =
    MOI.supports(_inner(model), sub)

function MOI.submit(model::ScaledOptimizer, sub::MOI.AbstractSubmittable, args...)
    return MOI.submit(_inner(model), sub, args...)
end

MOI.supports_incremental_interface(model::ScaledOptimizer) =
    MOI.supports_incremental_interface(_inner(model))

MOI.copy_to(dest::ScaledOptimizer, src::MOI.ModelLike) =
    MOI.Utilities.default_copy_to(dest, src)

function MOI.Utilities.final_touch(model::ScaledOptimizer, index_map)
    return MOI.Utilities.final_touch(_inner(model), index_map)
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
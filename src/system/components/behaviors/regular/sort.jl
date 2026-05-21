"""
Sort behaviors.
"""

# priority for behaviors
# priority is highest for first elements
const BEHAVIORS_PRIORITY = (AbstractJointFlowData, CapacityMultiplier, AbstractCapacityData, Duration, AbstractUnitCommitmentData)

# for ProfileSource, the capacity must be defined before joint flows
# because their flow is undefined before it is associated with a capacity
const BEHAVIORS_PRIORITY_PROFILE = (CapacityMultiplier, AbstractCapacityData, Duration, AbstractJointFlowData, AbstractUnitCommitmentData)

_sort_order(::AbstractModel) = BEHAVIORS_PRIORITY
_sort_order(::ProfileSourceModel) = BEHAVIORS_PRIORITY_PROFILE
_sort_order(::ProfileSinkModel) = BEHAVIORS_PRIORITY_PROFILE

# Identical behavior data is most likely an accidental duplicate in user input.
function _assert_unique_behaviordata(v::AbstractVector)
    for (i, b) in enumerate(v)
        for (j, other) in enumerate(v)
            j <= i && continue
            if isequal(b, other)
                throw(ArgumentError("Duplicate behavior data at positions $i and $j: $(typeof(b))"))
            end
        end
    end
    return nothing
end

# sort the behaviors using BEHAVIORS_PRIORITY as a priority list for behavior type
function _sortbehaviordata(v::AbstractVector, m::AbstractModel)
    _sorted = Vector{AbstractBehaviorData}(undef,0)
    matched = falses(length(v))
    for B in _sort_order(m)
        for (i, b) in enumerate(v)
            if b isa B
                matched[i] && continue
                push!(_sorted, b)
                matched[i] = true
            end
        end
    end
    for (i, b) in enumerate(v)
        matched[i] && continue
        push!(_sorted, b)
    end
    return _sorted
end

"""
Sort behaviors.
"""

# priority for behaviors
# priority is highest for first elements
const BEHAVIORS_PRIORITY = (AbstractJointFlowData, CapacityMultiplier, AbstractCapacityData, Duration, UnitCommitment)

# for ProfileSource, the capacity must be defined before joint flows
# because their flow is undefined before it is associated with a capacity
const BEHAVIORS_PRIORITY_PROFILE = (CapacityMultiplier, AbstractCapacityData, Duration, AbstractJointFlowData, UnitCommitment)

_sort_order(::AbstractModel) = BEHAVIORS_PRIORITY
_sort_order(::ProfileSourceModel) = BEHAVIORS_PRIORITY_PROFILE

# sort the behaviors using BEHAVIORS_PRIORITY as a priority list for behavior type
function _sortbehaviordata(v::AbstractVector, m::AbstractModel)
    _sorted = Vector{AbstractBehaviorData}(undef,0)
    for B in _sort_order(m)
        for b in v
            if b isa B
                push!(_sorted, b)
            end
        end
    end
    other = setdiff(v, _sorted) # behaviors which type is not included in BEHAVIORS_PRIORITY have lowest priority
    push!(_sorted, other...)
    return _sorted
end
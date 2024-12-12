"""
Sort behaviors.
"""

# priority for behaviors
# priority is highest for first elements
const BEHAVIORS_PRIORITY = (AbstractJointFlowData, CapacityMultiplier, AbstractCapacityData,)

# function _getjointflowdata(v::AbstractVector)
#     _jointflowdata = Vector{AbstractJointFlowData}(undef,0)
#     for b in v
#         if b isa AbstractJointFlowData
#             push!(_jointflowdata, b)
#         end
#     end
#     return _jointflowdata
# end

# sort the behaviors using BEHAVIORS_PRIORITY as a priority list for behavior type
function _sortbehaviordata(v::AbstractVector)
    _sorted = Vector{AbstractBehaviorData}(undef,0)
    for B in BEHAVIORS_PRIORITY
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
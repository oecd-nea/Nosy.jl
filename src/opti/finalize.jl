"""
Finalization of systems.
"""

# verify that all components are fully connected, throw an error otherwise
# apply all the node constraints
function finalize!(s::Snapshot)
    # check all nodes are connected
    assertconnected(s) # throw an error if all components are not fully connected

    # apply the snapshot constraints, which include the node constraints
    # NB component constraints are not applied at this step, but at Component constructor
    apply_constraints!(s)

    set_finalized!(s)
end
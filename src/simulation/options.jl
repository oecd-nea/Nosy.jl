"""
Management of options at the level of the simulation.
"""

# return the default options for the simulation
function _defaultoptions()
    return Dict{Symbol,Any}(
        
        # scaling of constraints
        :scalingtarget => 1, # rescale all constraints so that minimum * maximum factors (excl. constant) is equal to that
        :expthreshold => 0., # relative threshold for removing constraint terms; zero keeps every term
        
        # cleaning objective function
        :objthreshold => 0., # relative threshold for filtering and rounding objective terms; zero keeps the objective exact

        # fixing unimportant variables
        :boundthreshold => 0., # positive variables with upper bound at most that are fixed to zero; zero disables cleanup
    )
end

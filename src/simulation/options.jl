"""
Management of options at the level of the simulation.
"""

# return the default options for the simulation
function _defaultoptions()
    return Dict{Symbol,Any}(
        
        # scaling of constraints
        :scalingtarget => 1, # rescale all constraints so that minimum * maximum factors (excl. constant) is equal to that
        :expthreshold => 1E-9, # constraints terms with absolute value of factor lower than that are removed
        
        # cleaning objective function
        :objthreshold => 1E-9, # in the objective expression, remove terms with factor lower than that

        # fixing unimportant variables
        :boundthreshold => 1E-3, # positive variables with upper bound lower than that are fixed to zero
    )
end
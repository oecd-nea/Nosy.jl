using JuMP: Model

"""
Sim: data structure containing the information shared with all the simulation.
"""
struct Sim
    mesh::TimeMesh
    model::Model
    options::Dict{String,Any}
end

"""
    Sim(mesh::TimeMesh, model::Model; options)
Return a Sim based on the TimeMesh `mesh` and the JuMP model `model`.
Optional arguments:
  * `options`: Dict containing options for the simulation
"""
function Sim(mesh::TimeMesh, model::Model; options::Dict=_defaultoptions())
    return Sim(
        mesh,
        model,
        options
    )
end


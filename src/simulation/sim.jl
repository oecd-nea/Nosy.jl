using JuMP: Model, num_constraints, num_variables, list_of_constraint_types, solver_name

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

nsteps(s::Sim) = nsteps(s.mesh)
nhours(s::Sim) = nhours(s.mesh)
eachstep(s::Sim) = eachstep(s.mesh)
eachhour(s::Sim) = eachhour(s.mesh)

# count the constraints of a Sim
# snippet from: https://discourse.julialang.org/t/num-constraints-to-return-the-total-number-of-constraints/65488
_nconstraints(m::Model) = sum(num_constraints(m, F, S) for (F, S) in list_of_constraint_types(m))
nconstraints(s::Sim) = _nconstraints(s.model)

# count the variables of a Sim
nvariables(s::Sim) = num_variables(s.model)

# display sim info
function Base.show(io::IO, s::Sim)
    ns = nsteps(s)
    nh = nhours(s)
    sn = solver_name(s.model)
    print(
        io, 
        "Simulation ($nh hours, $ns timesteps, $sn)"
    )
end
using JuMP: Model, num_constraints, num_variables, list_of_constraint_types, solver_name

"""
Sim: data structure containing the information shared with all the simulation.
"""
struct Sim
    mesh::RTimeMesh
    model::JuMP.AbstractModel # abstract type, would be unpractical to have parametric Sim
    options::Dict{Symbol,Any}
    suffix::String # suffix for variable names
end

"""
    Sim(model::JuMP.AbstractModel; mesh::RTimeMesh=TimeMesh())
Return a Sim based on the JuMP model `model`.
Optional arguments:
  * `mesh`: TimeMesh for the simulation (default: 8760 hours, 1 step per hour)
"""
function Sim(
    model::JuMP.AbstractModel;
    mesh::RTimeMesh=TimeMesh(),
    suffix::String="",
)
    return Sim(
        mesh,
        model,
        _defaultoptions(),
        suffix
    )
end

"""
    Sim(optimizer_constructor; constraint_scaling=true, kwargs...)
Build a `JuMP.Model` from `optimizer_constructor` and return a `Sim`.
By default, scalar affine constraints are scaled before they reach the solver.
Extra keyword arguments override simulation options.
"""
function Sim(
    optimizer_constructor;
    mesh::RTimeMesh=TimeMesh(),
    suffix::String="",
    constraint_scaling::Bool=true,
    kwargs...,
)
    options = _defaultoptions()
    for (key, value) in pairs(kwargs)
        haskey(options, key) ||
            throw(ArgumentError("Unknown simulation option $key"))
        options[key] = value
    end
    factory = constraint_scaling ?
        ScaledOptimizer(
            optimizer_constructor;
            target=options[:scalingtarget],
            expthreshold=options[:expthreshold],
        ) :
        optimizer_constructor
    return Sim(mesh, JuMP.Model(factory), options, suffix)
end

nsteps(s::Sim) = nsteps(s.mesh)
nhours(s::Sim) = nhours(s.mesh)
eachstep(s::Sim) = eachstep(s.mesh)
eachhour(s::Sim) = eachhour(s.mesh)

"""
    lowermodel(s::Sim)
Return the lower model of a Bilevel problem or the model itself for a single-level problem.
"""
lowermodel(s::Sim) = Lower(s.model)

"""
    uppermodel(s::Sim)
Return the upper model of a Bilevel problem or the model itself for a single-level problem.
"""
uppermodel(s::Sim) = Upper(s.model)

"""
    model(s::Sim)
Return the JuMP model of the simulation for a single-level problem.
"""
model(s::Sim) = _model(s.model)

exptype(s::Sim) = _exptype(s.model)
_exptype(::JuMP.Model) = AffExpr
_exptype(::BilevelJuMP.BilevelModel) = BilevelJuMP.BilevelAffExpr

# count the constraints of a Sim
# snippet from: https://discourse.julialang.org/t/num-constraints-to-return-the-total-number-of-constraints/65488
function _nconstraints(m::Model) 
    l = list_of_constraint_types(m)
    if isempty(l)
        return 0
    else
        return sum(num_constraints(m, F, S) for (F, S) in l)
    end
end
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

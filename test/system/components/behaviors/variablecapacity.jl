using Nosy: mass, energy, co2
using Nosy: Sim, TimeMesh, nsteps, nvariables, nconstraints, sim
using Nosy: buildbehavior
using Nosy: VariableCapacity, VariableCapacityBehavior, _capacity, _nbunits, nbunits
using Nosy: getbehaviors
using Nosy: BasicConverter, ProfileSource, Demand
using Nosy: MassCarrier, EnergyCarrier
using Nosy: LinkedJointFlow, capacity
using Nosy: Component
using JuMP: Model, @variable, @objective, GenericAffExpr, lower_bound, has_upper_bound, value, set_silent
import JuMP
using ArgCheck: ArgumentError
using Test
import HiGHS

@testset "VariableCapacity" begin

    tsim() = Sim(Model(), mesh=TimeMesh(fill(1//2, 10)))

    getvariable(e::GenericAffExpr) = first(e.terms)[1]

    function makecomp(vbehavior=[])
        s = tsim()    
        mc = MassCarrier("m", s, energy=[1,2,3,4,5])
        ec = EnergyCarrier("e", s)
        d = BasicConverter(mc, ec)
        c = Component("comp", d, vbehavior)
        return c
    end

    let m = makecomp()  

        c = VariableCapacity(
            "input",
            mass,
            lb = 5,
            ub = Inf64,
        )  

        b = buildbehavior(m, c)

        @test _capacity(b) isa GenericAffExpr

        var = getvariable(_capacity(b))
        @test lower_bound(var) == 5.
        @test !has_upper_bound(var)

    end

    let m = makecomp()  

        c = VariableCapacity(
            "input",
            mass,
            unitsize=2.5
        )

        b = buildbehavior(m, c)

        @test _nbunits(b) isa GenericAffExpr
        @test _nbunits(b) == _capacity(b) / 2.5

    end

    @test_throws ArgumentError VariableCapacity(
        "input",
        mass, 
        lb = -5., # negative bound is not allowed
        ub = Inf64,
    )

    @test_throws ArgumentError VariableCapacity(
        "input",
        mass, 
        lb = 5., 
        ub = 3., # upper bound lower than lower bound
    )  

    let m = makecomp()

        c = VariableCapacity(
            "level", # no port has this name in the model d
            mass,
            lb = 5,
            ub = Inf64,
        )
        # port not found in the model
        @test_throws ArgumentError buildbehavior(m, c)
    end

    let m = makecomp()

        c = VariableCapacity("input",
            co2, # input port is not compatible with this modifier
            lb = 5,
            ub = Inf64,
        )  
        # port not compatible with modifier
        @test_throws ArgumentError buildbehavior(m, c)
    end

    let c = makecomp([VariableCapacity("input", mass)])

        @test isnothing(nbunits(c))

    end

    let c = makecomp([VariableCapacity("input", mass, unitsize=2.5)])

        @test nbunits(c) isa GenericAffExpr
        @test nbunits(c) == capacity(c) / 2.5

    end

    # no behaviors, no joint flows
    let c = makecomp([])
       
        # model has 10 timesteps
        # it should have 10 variables 
        #   flow @ converter @ each step (10),
        # and 10 constraints
        #   converter input lower bound = 0 @ each step (10),
        #   converter input upper bound <= Inf @ each step (0),
        @test nvariables(sim(c)) == 10
        @test nconstraints(sim(c)) == 10

    end


    # 1 behavior (variable capacity), no joint flows
    let c = makecomp([VariableCapacity("input", mass, lb=5, ub=Inf64)])

        # model has 10 timesteps
        # it should have 11 variables 
        #   flow @ converter @ each step (10),
        #   capacity (1)
        # and 21 constraints
        #   converter input lower bound = 0 @ each step (10),
        #   converter input upper bound <= Inf @ each step (0),
        #   converter input flow <= capacity @ each step (10),
        #   capacity >= cap lower bound (1),
        @test nvariables(sim(c)) == 11
        @test nconstraints(sim(c)) == 21

    end

    # 1 behavior (variable capacity), no joint flows, unit size (not integer)
    let c = makecomp([VariableCapacity("input", mass, lb=5, ub=Inf64, unitsize=2.5)])

        # model has 10 timesteps
        # it should have 11 variables 
        #   flow @ converter @ each step (10),
        #   capacity (1)
        # and 21 constraints
        #   converter input lower bound = 0 @ each step (10),
        #   converter input upper bound <= Inf @ each step (0),
        #   converter input flow <= capacity @ each step (10),
        #   capacity >= cap lower bound (1),
        # unit size must not change the number of variables or constraints
        @test nvariables(sim(c)) == 11
        @test nconstraints(sim(c)) == 21

    end

    # 1 behavior (variable capacity), no joint flows, unit size (integer)
    let c = makecomp([VariableCapacity("input", mass, lb=5, ub=Inf64, unitsize=2.5, integer=true)])

        # model has 10 timesteps
        # it should have 11 variables 
        #   flow @ converter @ each step (10),
        #   capacity (1)
        # and 22 constraints
        #   converter input lower bound = 0 @ each step (10),
        #   converter input upper bound <= Inf @ each step (0),
        #   converter input flow <= capacity @ each step (10),
        #   capacity >= cap lower bound (1),
        #   number of units is integer (1),
        @test nvariables(sim(c)) == 11
        @test nconstraints(sim(c)) == 22

    end

    function makecompwjoint(vbehavior=[])
        s = tsim()    
        mc = MassCarrier("m", s, energy=[1,2,3,4,5])
        ec = EnergyCarrier("e", s)
        d = BasicConverter(mc, ec)
        j = LinkedJointFlow("jflow", mc, :output, "input", x->x[1]) # output joint flow carrying mass
        c = Component("comp", d, [j, vbehavior...])
        return c
    end

    # 1 behavior (fixed capacity), joint flow
    let c = makecompwjoint([VariableCapacity("jflow", mass, lb=5.)])

        # model has 10 timesteps
        # it should have 11 variables 
        #   flow @ converter @ each step (10),
        #   capacity (1)
        # and 21 constraints
        #   converter input lower bound = 0 @ each step (10),
        #   converter input upper bound <= Inf @ each step (0),
        #   converter joint flow <= capacity @ each step (10),
        #   capacity >= cap lower bound (1),
        @test nvariables(sim(c)) == 11
        @test nconstraints(sim(c)) == 21

    end

    # profile source are a special case for capacity
    # constraints are not applied to output but to hidden capacity
    function makeprofilesource()
        s = tsim()    
        mc = MassCarrier("m", s, energy=[1,2,3,4,5])
        d = ProfileSource(mc,[0.1,0.2,0.3,0.4,0.5])
        cap = VariableCapacity("output", mass, lb=5., ub=Inf64)
        c = Component("profile", d, [cap])
        return c
    end

    let m = makeprofilesource()  

        @test nvariables(sim(m)) == 1 # variable capacity
        @test nconstraints(sim(m)) == 1 # variable cap lb

    end
    

    # profile source + capacity on non-default modifier
    function makeprofilesourcenondefault()
        s = tsim()    
        mc = MassCarrier("m", s, energy=[1,2,3,4,5])
        d = ProfileSource(mc,[0.1,0.2,0.3,0.4,0.5])
        cap = VariableCapacity("output", energy, lb=5., ub=Inf64) # NB energy instead of mass
        c = Component("profile", d, [cap])
        return c
    end

    @test_throws ArgumentError makeprofilesourcenondefault()

    # consumption not compatible with capacity
    function makeconsumption()
        s = tsim()    
        mc = MassCarrier("m", s, energy=[1,2,3,4,5])
        d = Demand(mc,[0.1,0.2,0.3,0.4,0.5])
        cap = VariableCapacity("output", energy, lb=5., ub=Inf64)
        c = Component("profile", d, [cap])
        return c
    end

    @test_throws ArgumentError makeconsumption()

    # linked capacity, reuse an existing affine expression as capacity
    let
        s = tsim()
        shared_cap = @variable(s.model, base_name="shared_cap", lower_bound=0.0)
        cap_expr = 1.0 * shared_cap
        mc = MassCarrier("m", s, energy=[1,2,3,4,5])
        ec = EnergyCarrier("e", s)
        d = BasicConverter(mc, ec)
        cap = VariableCapacity("input", mass; expression=cap_expr, lb=3.0, ub=40.0, unitsize=2.5)
        nvars_before = nvariables(s) # only `shared_cap` exists before the component is built
        c = Component("comp", d, [cap])
        @test nvariables(s) == nvars_before + nsteps(s) # no extra variable for capacity
        vb = first(getbehaviors(c, VariableCapacityBehavior))
        @test _capacity(vb) isa GenericAffExpr
        @test lower_bound(shared_cap) == 0.0
        @test nbunits(c) == capacity(c) / 2.5
    end

    # linked capacity, lb/ub enforced as constraints on the expression
    let
        s = Sim(Model(HiGHS.Optimizer), mesh=TimeMesh(fill(1//2, 10)))
        shared_cap = @variable(s.model, base_name="shared_cap")
        cap_expr = 1.0 * shared_cap
        mc = MassCarrier("m", s, energy=[1,2,3,4,5])
        ec = EnergyCarrier("e", s)
        d = BasicConverter(mc, ec)
        cap = VariableCapacity("input", mass; expression=cap_expr, lb=2.0, ub=15.0)
        c = Component("comp", d, [cap])
        set_silent(s.model)
        @objective(s.model, Max, shared_cap)
        JuMP.optimize!(s.model)
        @test isapprox(value(shared_cap), 15.0)
    end

    # expression variable: integer=true is allowed and applied on reused variable
    let
        s = tsim()
        shared_cap = @variable(s.model, base_name="shared_cap", lower_bound=0.0)
        mc = MassCarrier("m", s, energy=[1,2,3,4,5])
        ec = EnergyCarrier("e", s)
        d = BasicConverter(mc, ec)
        cap = VariableCapacity("input", mass; expression=shared_cap, integer=true)
        Component("comp", d, [cap])
        @test JuMP.is_integer(shared_cap)
    end

    # affine expression: integer=true is rejected at constructor
    let
        s = tsim()
        shared_cap = @variable(s.model, base_name="shared_cap", lower_bound=0.0)
        @test_throws ArgumentError VariableCapacity("input", mass; expression=1.0 * shared_cap, integer=true)
    end

    # warmstart is not compatible with variable expression
    let
        s = tsim()
        shared_cap = @variable(s.model, base_name="shared_cap", lower_bound=0.0)
        @test_throws ArgumentError VariableCapacity("input", mass; expression=shared_cap, warmstart=1.0)
    end

    # warmstart is not compatible with affine expression
    let
        s = tsim()
        shared_cap = @variable(s.model, base_name="shared_cap", lower_bound=0.0)
        @test_throws ArgumentError VariableCapacity("input", mass; expression=1.0 * shared_cap, warmstart=1.0)
    end

    # warmstart is not compatible with Number expression
    let
        @test_throws ArgumentError VariableCapacity("input", mass; expression=10.0, warmstart=1.0)
    end

    # Number expression: integer=true still gives fixed capacity bounds
    let
        m = makecomp()
        c = VariableCapacity("input", mass; expression=10.0, integer=true)
        b = buildbehavior(m, c)
        var = getvariable(_capacity(b))
        @test lower_bound(var) == 10.0
        @test JuMP.upper_bound(var) == 10.0
    end

    # expression variable: lb/ub are enforced as constraints on reused variable
    let
        s = Sim(Model(HiGHS.Optimizer), mesh=TimeMesh(fill(1//2, 10)))
        shared_cap = @variable(s.model, base_name="shared_cap")
        mc = MassCarrier("m", s, energy=[1,2,3,4,5])
        ec = EnergyCarrier("e", s)
        d = BasicConverter(mc, ec)
        cap = VariableCapacity("input", mass; expression=shared_cap, lb=2.0, ub=15.0)
        Component("comp", d, [cap])
        set_silent(s.model)
        @objective(s.model, Max, shared_cap)
        JuMP.optimize!(s.model)
        @test isapprox(value(shared_cap), 15.0)
    end

end

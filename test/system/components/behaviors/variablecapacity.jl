using POSY2: mass
using POSY2: Sim, TimeMesh, nvariables, nconstraints
using POSY2: build, buildbehavior
using POSY2: VariableCapacity, VariableCapacityBehavior, _capacity
using POSY2: BasicConverter
using POSY2: MassCarrier, EnergyCarrier
using POSY2: mass, energy
using POSY2: Component
using JuMP: Model, AffExpr, lower_bound, upper_bound, has_lower_bound, has_upper_bound
using ArgCheck: ArgumentError

@testset "VariableCapacity" begin

    tsim() = Sim(TimeMesh(fill(1//2, 10)), Model())

    getvariable(e::AffExpr) = first(e.terms)[1]

    function makeconv()
        s = tsim()    
        mc = MassCarrier("m", s, energy=[1,2,3,4,5])
        ec = EnergyCarrier("e", s)
        d = BasicConverter(
            mc,
            ec,
        )        
        m = build(d, "conv")
        return m
    end

    let m = makeconv()  

        c = VariableCapacity(
            "input",
            mass,
            lb = 5,
            ub = Inf64,
        )  

        b = buildbehavior(m, "comp", c)

        @test _capacity(b) isa AffExpr

        var = getvariable(_capacity(b))
        @test lower_bound(var) == 5.
        @test !has_upper_bound(var)

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

    let m = makeconv()

        c = VariableCapacity(
            "level", # no port has this name in the model d
            mass,
            lb = 5,
            ub = Inf64,
        )
        # port not found in the model
        @test_throws ArgumentError buildbehavior(m, "test", c)
    end

    let m = makeconv()

        c = VariableCapacity("input",
            co2, # input port is not compatible with this modifier
            lb = 5,
            ub = Inf64,
        )  
        # port not compatible with modifier
        @test_throws ArgumentError buildbehavior(m, "test", c)
    end


    # tests on Component

    function makecomp(vbehavior)
        s = tsim()    
        mc = MassCarrier("m", s, energy=[1,2,3,4,5])
        ec = EnergyCarrier("e", s)
        d = BasicConverter(mc, ec)
        c = Component("comp", d, vbehavior)
        return c
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

    
end
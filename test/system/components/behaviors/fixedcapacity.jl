using Nosy: mass
using Nosy: Sim, TimeMesh, nvariables, nconstraints
using Nosy: build, buildbehavior
using Nosy: FixedCapacity, FixedCapacityBehavior, _capacity, _nbunits, nbunits
using Nosy: BasicConverter, ProfileSource, Demand
using Nosy: MassCarrier, EnergyCarrier
using Nosy: mass, energy
using Nosy: Component
using JuMP: Model, AffExpr, lower_bound, upper_bound, has_lower_bound, has_upper_bound
using ArgCheck: ArgumentError

@testset "FixedCapacity" begin

    tsim() = Sim(Model(), mesh=TimeMesh(fill(1//2, 10)))

    function makecomp(vbehavior=[])
        s = tsim()    
        mc = MassCarrier("m", s, energy=[1,2,3,4,5])
        ec = EnergyCarrier("e", s)
        d = BasicConverter(mc, ec)
        c = Component("comp", d, vbehavior)
        return c
    end

    let m = makecomp()  

        c = FixedCapacity(
            "input",
            mass,
            5 # should be converted to Float by FixedCapacity constructor
        )

        b = buildbehavior(m, c)

        @test _capacity(b) == 5.
        @test isnothing(_nbunits(b))
        
    end

    let m = makecomp()  

        c = FixedCapacity(
            "input",
            mass,
            5, # should be converted to Float by FixedCapacity constructor
            unitsize=2.5
        )

        b = buildbehavior(m, c)

        @test _capacity(b) == 5.
        @test _nbunits(b) == 2.
        
    end

    @test_throws ArgumentError FixedCapacity(
        "input",
        mass, 
        -5., # negative value is not allowed
    )


    let m = makecomp()

        c = FixedCapacity(
            "level", # no port has this name in the model d
            mass,
            5,
        )
        # port not found in the model
        @test_throws ArgumentError buildbehavior(m, c)
    end

    let m = makecomp()

        c = FixedCapacity("input",
            co2, # input port is not compatible with this modifier
            5,
        )  
        # port not compatible with modifier
        @test_throws ArgumentError buildbehavior(m, c)
    end

    let c = makecomp([FixedCapacity("input", mass, 5)])

        @test isnothing(nbunits(c))

    end

    let c = makecomp([FixedCapacity("input", mass, 5, unitsize=2.5)])

        @test nbunits(c) == 2.

    end

    # no behaviors, no joint flows
    let c = makecomp()
       
        # model has 10 timesteps
        # it should have 10 variables 
        #   flow @ converter @ each step (10),
        # and 10 constraints
        #   converter input lower bound = 0 @ each step (10),
        #   converter input upper bound <= Inf @ each step (0),
        @test nvariables(sim(c)) == 10
        @test nconstraints(sim(c)) == 10

    end


    # 1 behavior (fixed capacity), no joint flows
    let c = makecomp([FixedCapacity("input", mass, 5)])

        # model has 10 timesteps
        # it should have 10 variables 
        #   flow @ converter @ each step (10),
        # and 21 constraints
        #   converter input lower bound = 0 @ each step (10),
        #   converter input upper bound <= Inf @ each step (0),
        #   converter input flow <= capacity @ each step (10),
        @test nvariables(sim(c)) == 10
        @test nconstraints(sim(c)) == 20

    end

    # 1 behavior (fixed capacity), no joint flows, unit size
    let c = makecomp([FixedCapacity("input", mass, 5, unitsize=2.5)])

        # model has 10 timesteps
        # it should have 10 variables 
        #   flow @ converter @ each step (10),
        # and 21 constraints
        #   converter input lower bound = 0 @ each step (10),
        #   converter input upper bound <= Inf @ each step (0),
        #   converter input flow <= capacity @ each step (10),
        # unit size must not change the number of variables or constraints
        @test nvariables(sim(c)) == 10
        @test nconstraints(sim(c)) == 20

    end

    function makecompwjoint(vbehavior=[])
        s = tsim()    
        mc = MassCarrier("m", s, energy=[1,2,3,4,5])
        ec = EnergyCarrier("e", s)
        d = BasicConverter(mc, ec)
        j = LinkedJointFlow("jflow", mc, :output, "input", x->x) # output joint flow carrying mass
        c = Component("comp", d, [j, vbehavior...])
        return c
    end

    # 1 behavior (fixed capacity), joint flow
    let c = makecompwjoint([FixedCapacity("jflow", mass, 5)])

        # model has 10 timesteps
        # it should have 10 variables 
        #   flow @ converter @ each step (10),
        # and 21 constraints
        #   converter input lower bound = 0 @ each step (10),
        #   converter input upper bound <= Inf @ each step (0),
        #   converter joint flow <= capacity @ each step (10),
        @test nvariables(sim(c)) == 10
        @test nconstraints(sim(c)) == 20

    end

    # profile source are a special case for capacity
    # constraints are not applied to output but to hidden capacity
    function makeprofilesource()
        s = tsim()    
        mc = MassCarrier("m", s, energy=[1,2,3,4,5])
        d = ProfileSource(mc,[0.1,0.2,0.3,0.4,0.5])
        cap = FixedCapacity("output", mass, 5.)
        c = Component("profile", d, [cap])
        return c
    end

    let m = makeprofilesource()  

        @test nvariables(sim(m)) == 1 # profile source inner capacity
        @test nconstraints(sim(m)) == 2 # profile source inner cap lb, equality of inner cap and fixed cap

    end
    

    # profile source + capacity on non-default modifier
    function makeprofilesourcenondefault()
        s = tsim()    
        mc = MassCarrier("m", s, energy=[1,2,3,4,5])
        d = ProfileSource(mc,[0.1,0.2,0.3,0.4,0.5])
        cap = FixedCapacity("output", energy, 5.) # NB energy instead of mass
        c = Component("profile", d, [cap])
        return c
    end

    @test_throws ArgumentError makeprofilesourcenondefault()

end
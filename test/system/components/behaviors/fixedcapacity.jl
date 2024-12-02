using POSY2: mass
using POSY2: Sim, TimeMesh, nvariables, nconstraints
using POSY2: build, buildbehavior
using POSY2: FixedCapacity, FixedCapacityBehavior, _capacity
using POSY2: BasicConverter
using POSY2: MassCarrier, EnergyCarrier
using POSY2: mass, energy
using POSY2: Component
using JuMP: Model, AffExpr, lower_bound, upper_bound, has_lower_bound, has_upper_bound
using ArgCheck: ArgumentError

@testset "FixedCapacity" begin

    tsim() = Sim(TimeMesh(fill(1//2, 10)), Model())

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

        c = FixedCapacity(
            "input",
            mass,
            5 # should be converted to Float by FixedCapacity constructor
        )

        b = buildbehavior(m, "comp", c)

        @test _capacity(b) == 5.
        
    end

    @test_throws ArgumentError FixedCapacity(
        "input",
        mass, 
        -5., # negative value is not allowed
    )


    let m = makeconv()

        c = FixedCapacity(
            "level", # no port has this name in the model d
            mass,
            5,
        )
        # port not found in the model
        @test_throws ArgumentError buildbehavior(m, "test", c)
    end

    let m = makeconv()

        c = FixedCapacity("input",
            co2, # input port is not compatible with this modifier
            5,
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

    
end
using POSY2: mass, energy
using POSY2: Sim, TimeMesh
using POSY2: build
using POSY2: VariableCapacity, FixedCapacity
using POSY2: BasicConverter
using POSY2: OvernightCost, OvernightCostBehavior
using POSY2: overnightcost, _overnightcost
using POSY2: MassCarrier, EnergyCarrier
using POSY2: mass, energy
using POSY2: Component
using JuMP: Model, AffExpr
using ArgCheck: ArgumentError

@testset "OvernightCost" begin


    let b = OvernightCost("input", mass, 5)

        # conversion to Float64
        @test b.val == 5.

    end


    # no negative cost
    @test_throws ArgumentError OvernightCost("input", mass, -5.)

    tsim() = Sim(TimeMesh(fill(1//2, 10)), Model())

    function makeconv(vb)
        s = tsim()    
        mc = MassCarrier("m", s, energy=[1,2,3,4,5])
        ec = EnergyCarrier("e", s)
        d = BasicConverter(
            mc,
            ec,
        )   
        c = Component("comp", d, vb)
        return c
    end

    # NB: overnight cost is given before capacity
    # constructor should re-order behaviors     
    let m = makeconv([OvernightCost("input", mass, 10.), FixedCapacity("input", mass, 5.)])  

        # test: behaviors are re-ordered (capacity before cost)
        @test m.behaviors[1] isa FixedCapacityBehavior{AffExpr} && m.behaviors[2] isa OvernightCostBehavior{AffExpr}

        # adapting to fixed capacity
        @test _overnightcost(m.behaviors[2]) == AffExpr(5. * 10.)

        # component metric
        @test overnightcost(m) == AffExpr(5. * 10.)

    end


    let m = makeconv([OvernightCost("input", mass, 10.), VariableCapacity("input", mass)])

        # adapting to variable capacity
        @test _overnightcost(m.behaviors[2]) == _capacity(m.behaviors[1]) * 10.

        # component metric
        @test overnightcost(m) == _capacity(m.behaviors[1]) * 10.

    end

    # no overnight cost
    let m = makeconv([])

        @test overnightcost(m) == 0. # Float64

    end

    # incompatible port names
    @test_throws ArgumentError makeconv([OvernightCost("input", mass, 10.), VariableCapacity("output", mass)])

    # incompatible port modifiers
    @test_throws AssertionError makeconv([OvernightCost("input", mass, 10.), VariableCapacity("input", energy)])

end
using POSY2: mass, energy
using POSY2: Sim, TimeMesh
using POSY2: build
using POSY2: VariableCapacity, FixedCapacity
using POSY2: BasicConverter
using POSY2: FixedCost, FixedCostBehavior
using POSY2: fixedcost, _fixedcost
using POSY2: MassCarrier, EnergyCarrier
using POSY2: mass, energy
using POSY2: Component
using JuMP: Model, AffExpr
using ArgCheck: ArgumentError

@testset "FixedCost" begin


    let b = FixedCost(:overnight, "input", mass, 5)

        # conversion to Float64
        @test b.val == 5.

    end


    # no negative cost
    @test_throws ArgumentError FixedCost(:overnight, "input", mass, -5.)

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

    # NB: fixed cost is given before capacity
    # constructor should re-order behaviors     
    let m = makeconv([FixedCost(:overnight, "input", mass, 10.), FixedCapacity("input", mass, 5.)])  

        # test: behaviors are re-ordered (capacity before cost)
        @test m.behaviors[1] isa FixedCapacityBehavior{AffExpr} && m.behaviors[2] isa FixedCostBehavior{AffExpr}

        # adapting to fixed capacity
        @test _fixedcost(m.behaviors[2]) == AffExpr(5. * 10.)

        # component metric
        @test fixedcost(m) == AffExpr(5. * 10.)

    end


    let m = makeconv([FixedCost(:overnight, "input", mass, 10.), VariableCapacity("input", mass)])

        # adapting to variable capacity
        @test _fixedcost(m.behaviors[2]) == _capacity(m.behaviors[1]) * 10.

        # component metric
        @test fixedcost(m) == _capacity(m.behaviors[1]) * 10.

    end

    # no fixed cost
    let m = makeconv([])

        @test fixedcost(m) == 0. # Float64

    end

    # incompatible port names
    @test_throws ArgumentError makeconv([FixedCost(:overnight, "input", mass, 10.), VariableCapacity(:"output", mass)])

    # incompatible port modifiers
    @test_throws AssertionError makeconv([FixedCost(:overnight, "input", mass, 10.), VariableCapacity("input", energy)])

end
using Nosy: mass
using Nosy: Sim, TimeMesh
using Nosy: ConstantCost, ConstantCostBehavior
using Nosy: constantcost, _constantcost
using Nosy: BasicConverter
using Nosy: MassCarrier, EnergyCarrier
using Nosy: Component
using JuMP: Model, AffExpr
using ArgCheck: ArgumentError
using Test

@testset "ConstantCost" begin

    let b = ConstantCost(:fixed_charge, 5)

        @test b.val == 5.

    end

    @test_throws ArgumentError ConstantCost(:fixed_charge, -5.)

    tsim() = Sim(Model(), mesh=TimeMesh(fill(1//2, 10)))

    function makeconv(vb)
        s = tsim()
        mc = MassCarrier("m", s, energy=[1,2,3,4,5])
        ec = EnergyCarrier("e", s)
        d = BasicConverter(mc, ec)
        c = Component("comp", d, vb)
        return c
    end

    let c = makeconv([ConstantCost(:fixed_charge, 10.)])

        @test c.behaviors[1] isa ConstantCostBehavior{AffExpr}
        @test _constantcost(c.behaviors[1]) == AffExpr(10.)
        @test constantcost(c) == AffExpr(10.)
        @test constantcost(c, :fixed_charge) == AffExpr(10.)
        @test constantcost(c, :other) == 0.

    end

    let c = makeconv([])

        @test constantcost(c) == 0.

    end

end

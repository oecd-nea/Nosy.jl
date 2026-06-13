using Nosy: mass
using Nosy: Sim, TimeMesh
using Nosy: VariableCapacity, FixedCapacity
using Nosy: FixedComposedCapacity
using Nosy: CapacityMultiplier, Duration
using Nosy: FixedCost, ConstantCost, VariableCost
using Nosy: BasicConverter, BasicStorage
using Nosy: MassCarrier, EnergyCarrier
using Nosy: mass, energy
using Nosy: Component, getport
using Nosy: capacity
using Nosy: nbunits
using Nosy: fixedcost, constantcost, variablecost, cost
using JuMP: Model, GenericAffExpr, AffExpr
using JuMP: has_upper_bound, lower_bound
using Test

@testset "Component metrics" begin

    tsim() = Sim(Model(), mesh=TimeMesh(fill(1//2, 10)))

    getvariable(e::GenericAffExpr) = first(e.terms)[1]

    function makecomp(vbehavior)
        s = tsim()    
        mc = MassCarrier("m", s, energy=[1,2,3,4,5,6,7,8,9,10])
        ec = EnergyCarrier("e", s)
        d = BasicConverter(mc, ec)
        c = Component("comp", d, vbehavior)
        return c
    end

    # no capacity behavior
    let c = makecomp([])

        @test capacity(c) == 0.
        @test fixedcost(c) == 0.
        @test constantcost(c) == 0.
        @test cost(c) == 0.
        @test nbunits(c) === nothing

    end    

    # variable capacity behavior
    let c = makecomp([VariableCapacity("input", mass, lb=5, ub=Inf64)])

        @test capacity(c) isa AffExpr
        @test_logs (:warn, r"No capacity") @test capacity(c, "output") == Inf64
        @test_throws AssertionError capacity(c, "missing")

        v = getvariable(capacity(c))
        @test lower_bound(v) == 5.
        @test !has_upper_bound(v)

    end

    let c = makecomp([FixedCapacity("input", mass, 5.), FixedCost(:overnight, "input", mass, 10.), ConstantCost(:fixed_charge, 7.), VariableCost(:fuel, "input", energy, 2.), VariableCost(:vom, "output", energy, 3.)])

        @test capacity(c) == 5.
        @test fixedcost(c) == AffExpr(5. * 10.)
        @test constantcost(c) == AffExpr(7.)

        # test selection based on cost type
        @test fixedcost(c, :overnight) == AffExpr(5. * 10.)
        @test fixedcost(c, :other) == 0.
        @test constantcost(c, :fixed_charge) == AffExpr(7.)
        @test constantcost(c, :other) == 0.
        @test variablecost(c) == sum(energy(getport(c, "input"))) * 2 + sum(energy(getport(c, "output"))) * 3
        @test variablecost(c, :fuel) == sum(energy(getport(c, "input"))) * 2
        @test variablecost(c, :vom) == sum(energy(getport(c, "output"))) * 3
        @test cost(c) == AffExpr(5. * 10.) + AffExpr(7.) + sum(energy(getport(c, "input"))) * 2 + sum(energy(getport(c, "output"))) * 3
        @test cost(c, :overnight) == fixedcost(c, :overnight)
        @test cost(c, :fixed_charge) == constantcost(c, :fixed_charge)
        @test cost(c, :fuel) == variablecost(c, :fuel)
        @test cost(c, :vom) == variablecost(c, :vom)

    end

    # capacity multiplier metrics
    let c = makecomp([FixedCapacity("input", mass, 10.), CapacityMultiplier("input", 0.1:0.1:1.0)])

        @test capacity(c) == 10.
        @test capacity(c; multiplier=true).data == collect(0.1:0.1:1.0) .* 10.

    end

    # multiple matching multipliers are rejected by the capacity metric
    let c = makecomp([FixedCapacity("input", mass, 10.), CapacityMultiplier("input", 0.5), CapacityMultiplier("input", 0.8)])

        @test_throws AssertionError capacity(c; multiplier=true)

    end

    # composed capacities match multipliers on any covered port
    let
        s = tsim()
        from = MassCarrier("from", s)
        to = MassCarrier("to", s)
        c = Component(
            "comp",
            BasicConverter(from, to),
            [FixedComposedCapacity(["input", "output"], mass, 10.), CapacityMultiplier("output", 0.1:0.1:1.0)],
        )

        @test capacity(c) == 10.
        @test capacity(c; multiplier=true).data == collect(0.1:0.1:1.0) .* 10.

    end

    # capacity derived from storage duration
    let
        s = tsim()
        mc = MassCarrier("m", s)
        c = Component("sto", BasicStorage(mc, modifier=mass), [FixedCapacity("input", mass, 10.), Duration(2.)])

        @test capacity(c, "input") == 10.
        @test capacity(c, "output") == 10.
        @test capacity(c, "level") == 20.

    end

    let
        s = tsim()
        mc = MassCarrier("m", s)
        c = Component("sto", BasicStorage(mc, modifier=mass), [FixedCapacity("level", mass, 20.), Duration(2.)])

        @test capacity(c, "level") == 20.
        @test capacity(c, "input") == 10.
        @test capacity(c, "output") == 10.

    end

    # number of units metric
    let c = makecomp([FixedCapacity("input", mass, 10., unitsize=2.)])

        @test nbunits(c) == 5.

    end

end

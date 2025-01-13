using Nosy: mass
using Nosy: Sim, TimeMesh
using Nosy: VariableCapacity, FixedCapacity
using Nosy: FixedCapacity, FixedCapacityBehavior
using Nosy: FixedCost, VariableCost
using Nosy: BasicConverter, BasicConverterModel
using Nosy: MassCarrier, EnergyCarrier
using Nosy: mass, energy
using Nosy: Component, model, sim
using Nosy: capacity
using Nosy: fixedcost, variablecost, cost
using JuMP: Model, AffExpr
using JuMP: has_lower_bound, has_upper_bound, lower_bound, upper_bound

@testset "Component metrics" begin

    tsim() = Sim(Model(), mesh=TimeMesh(fill(1//2, 10)))

    getvariable(e::AffExpr) = first(e.terms)[1]

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
        @test cost(c) == 0.

    end    

    # variable capacity behavior
    let c = makecomp([VariableCapacity("input", mass, lb=5, ub=Inf64)])

        @test capacity(c) isa AffExpr

        v = getvariable(capacity(c))
        @test lower_bound(v) == 5.
        @test !has_upper_bound(v)

    end

    let c = makecomp([FixedCapacity("input", mass, 5.), FixedCost(:overnight, "input", mass, 10.), VariableCost(:fuel, "input", energy, 2.), VariableCost(:vom, "output", energy, 3.)])

        @test capacity(c) == 5.
        @test fixedcost(c) == AffExpr(5. * 10.)

        # test selection based on cost type
        @test fixedcost(c, :overnight) == AffExpr(5. * 10.)
        @test fixedcost(c, :other) == 0.
        @test variablecost(c) == sum(energy(getport(c, "input"))) * 2 + sum(energy(getport(c, "output"))) * 3
        @test variablecost(c, :fuel) == sum(energy(getport(c, "input"))) * 2
        @test variablecost(c, :vom) == sum(energy(getport(c, "output"))) * 3
        @test cost(c) == AffExpr(5. * 10.) + sum(energy(getport(c, "input"))) * 2 + sum(energy(getport(c, "output"))) * 3
        @test cost(c, :overnight) == fixedcost(c, :overnight)
        @test cost(c, :fuel) == variablecost(c, :fuel)
        @test cost(c, :vom) == variablecost(c, :vom)

    end

end
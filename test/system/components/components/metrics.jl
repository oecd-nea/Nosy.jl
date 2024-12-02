using POSY2: mass
using POSY2: Sim, TimeMesh
using POSY2: VariableCapacity, FixedCapacity
using POSY2: FixedCapacity, FixedCapacityBehavior
using POSY2: OvernightCost
using POSY2: BasicConverter, BasicConverterModel
using POSY2: MassCarrier, EnergyCarrier
using POSY2: mass, energy
using POSY2: Component, model, sim
using POSY2: capacity
using POSY2: overnightcost
using JuMP: Model, AffExpr
using JuMP: has_lower_bound, has_upper_bound, lower_bound, upper_bound

@testset "Component metrics" begin

    tsim() = Sim(TimeMesh(fill(1//2, 10)), Model())

    getvariable(e::AffExpr) = first(e.terms)[1]

    function makecomp(vbehavior)
        s = tsim()    
        mc = MassCarrier("m", s, energy=[1,2,3,4,5])
        ec = EnergyCarrier("e", s)
        d = BasicConverter(mc, ec)
        c = Component("comp", d, vbehavior)
        return c
    end

    # no capacity behavior
    let c = makecomp([])

        @test capacity(c) == 0.
        @test overnightcost(c) == 0.

    end    

    # variable capacity behavior
    let c = makecomp([VariableCapacity("input", mass, lb=5, ub=Inf64)])

        @test capacity(c) isa AffExpr

        v = getvariable(capacity(c))
        @test lower_bound(v) == 5.
        @test !has_upper_bound(v)

    end

    let c = makecomp([FixedCapacity("input", mass, 5.), OvernightCost("input", mass, 10.)])

        @test capacity(c) == AffExpr(5.)
        @test overnightcost(c) == AffExpr(5. * 10.)

    end

end
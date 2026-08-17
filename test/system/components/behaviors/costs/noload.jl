using Nosy: energy
using Nosy: Sim, TimeMesh, sim
using Nosy: eachstep, weight
using Nosy: BasicConverter
using Nosy: NoLoadCost, NoLoadCostBehavior
using Nosy: UnitCommitment, FixedCapacity
using Nosy: _up
using Nosy: noloadcost, _noloadcost
using Nosy: MassCarrier, EnergyCarrier
using Nosy: Component
using JuMP: Model, AffExpr
using Test

@testset "NoLoadCost" begin

    tsim() = Sim(Model(), mesh=TimeMesh(fill(1//2, 10)))

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

    # no unit commitment behavior
    @test_throws AssertionError makeconv([NoLoadCost(:noload, "input", 10)])

    # no unit commitment behavior matching the port "input"
    @test_throws AssertionError makeconv(
        [
            UnitCommitment("output", 0.5), 
            NoLoadCost(:noload, "input", 10)
        ]
    )

    let c = makeconv([NoLoadCost(:noload, "input", 10), UnitCommitment("input", 0.5), FixedCapacity("input", energy, 5., unitsize=1)]) # no laod needs UC, UC needs capacity

        @test c.behaviors[3] isa NoLoadCostBehavior{AffExpr} # re-ordering because of behaviors priorities

        # adapting to fixed capacity
        @test _noloadcost(c.behaviors[3]) == 10 * sum(weight(sim(c).mesh, s) * _up(c.behaviors[2])[s] for s in eachstep(sim(c)))

        # component metric
        @test noloadcost(c) == _noloadcost(c.behaviors[3])

    end

    # no variable costs
    let c = makeconv([])

        @test noloadcost(c) == 0. # Float64 (reduce memory allocation)

    end

    # non-uniform mesh: the commitment state is a step function, so it must be integrated
    # with the interval sum and not with the trapezoid rule used by sum(::Stepwise)
    let
        s = Sim(Model(), mesh=TimeMesh([1//1, 1//2, 1//2, 2//1, 1//1, 2//1])) # 6 steps, 7 hours
        mc = MassCarrier("m", s, energy=[1,2,3,4,5,6,7])
        ec = EnergyCarrier("e", s)
        c = Component(
            "comp",
            BasicConverter(mc, ec),
            [NoLoadCost(:noload, "input", 10), UnitCommitment("input", 0.5), FixedCapacity("input", energy, 5., unitsize=1)],
        )

        uc = c.behaviors[2]
        nl = c.behaviors[3]
        @test nl isa NoLoadCostBehavior{AffExpr}

        @test _noloadcost(nl) == 10 * sum(weight(sim(c).mesh, st) * _up(uc)[st] for st in eachstep(sim(c)))

        # the trapezoid rule would give a different (wrong) result on this mesh
        @test _noloadcost(nl) != 10 * sum(_up(uc))
    end

end

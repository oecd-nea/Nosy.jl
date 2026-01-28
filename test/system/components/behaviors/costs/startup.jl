using Nosy: energy
using Nosy: Sim, TimeMesh, sim
using Nosy: eachstep
using Nosy: BasicConverter
using Nosy: FixedCapacity, UnitCommitment
using Nosy: StartupCost, StartupCostBehavior
using Nosy: startupcost, _startupcost
using Nosy: MassCarrier, EnergyCarrier
using Nosy: Component
using JuMP: Model, AffExpr
using Test

@testset "StartupCost" begin

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
    @test_throws AssertionError makeconv([StartupCost(:startup, "input", 10)])

    # no unit commitment behavior matching the port "input"
    @test_throws AssertionError makeconv(
        [
            UnitCommitment("output", 0.5), 
            StartupCost(:startup, "input", 10)
        ]
    )

    let c = makeconv([StartupCost(:startup, "input", 10), UnitCommitment("input", 0.5), FixedCapacity("input", energy, 5., unitsize=1)]) # startup cost needs UC, UC needs capacity

        @test c.behaviors[3] isa StartupCostBehavior{AffExpr} # re-ordering because of behaviors priorities

        @test _startupcost(c.behaviors[3]) == 10 * sum((c.behaviors[2]).startup[s] for s in eachstep(sim(c)))

        # component metric
        @test startupcost(c) == _startupcost(c.behaviors[3])

    end

    # no variable costs
    let c = makeconv([])

        @test startupcost(c) == 0. # Float64 (reduce memory allocation)

    end

end

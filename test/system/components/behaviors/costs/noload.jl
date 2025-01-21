using Nosy: mass, energy
using Nosy: Sim, TimeMesh
using Nosy: eachstep, weight
using Nosy: build
using Nosy: BasicConverter
using Nosy: LinkedJointFlow
using Nosy: NoLoadCost, NoLoadCostBehavior
using Nosy: _up
using Nosy: noloadcost, _noloadcost
using Nosy: MassCarrier, EnergyCarrier
using Nosy: mass, energy
using Nosy: Component, balance
using JuMP: Model, AffExpr
using ArgCheck: ArgumentError

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

end
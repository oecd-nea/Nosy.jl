using Nosy: mass, energy
using Nosy: Sim, TimeMesh
using Nosy: VariableCapacity, FixedCapacity
using Nosy: BasicConverter
using Nosy: capacity
using Nosy: MassCarrier, EnergyCarrier
using Nosy: Component, Node, Snapshot, connect!
using JuMP: Model, GenericAffExpr
using Test

@testset "Snapshot capacity" begin

    tsim() = Sim(Model(), mesh=TimeMesh(fill(1//2, 10)))

    function makeconv(s, vb)
        mc = MassCarrier("m", s, energy=[1,2,3,4,5])
        ec = EnergyCarrier("e", s)
        d = BasicConverter(
            mc,
            ec,
        )   
        c = Component("comp", d, vb)
        return c
    end

    function makesnapshot(vb)
        s = tsim()
        c = makeconv(s, vb)
        n = Node("mass node", c.model.data.input) # mass carrier node
        sn = Snapshot(s)
        connect!(sn, c, n)
        return sn
    end

    let s = makesnapshot([FixedCapacity("input", mass, 5.)])

        # fixed capacity
        @test capacity(s, "comp") == 5.

    end

    let s = makesnapshot([VariableCapacity("input", mass)])

        # variable capacity
        @test capacity(s, "comp") isa GenericAffExpr

    end

    let s = makesnapshot([])

        # component has no capacity
        @test capacity(s, "comp") == 0.

    end    

    let s = makesnapshot([])

        # no component with name `nocomp`
        @test_throws AssertionError capacity(s, "nocomp")

    end

end

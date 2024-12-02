using POSY2: mass, energy
using POSY2: Sim, TimeMesh
using POSY2: VariableCapacity, FixedCapacity
using POSY2: BasicConverter
using POSY2: overnightcost
using POSY2: MassCarrier, EnergyCarrier
using POSY2: Component, Node, Snapshot, connect!
using JuMP: Model, AffExpr
using ArgCheck: ArgumentError

@testset "Snapshot costs" begin

    tsim() = Sim(TimeMesh(fill(1//2, 10)), Model())

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

    let s = makesnapshot([FixedCapacity("input", mass, 5.), OvernightCost("input", mass, 10.)])

        # fixed capacity + overnight cost
        @test overnightcost(s, "comp") == AffExpr(5. * 10.)

    end

    let s = makesnapshot([])

        # no overnight costs
        @test overnightcost(s, "comp") == 0.

    end


    let s = makesnapshot([])

        # no component with name `nocomp`
        @test_throws AssertionError overnightcost(s, "nocomp")

    end

end
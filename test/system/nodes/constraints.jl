using Nosy: mass
using Nosy: Sim, TimeMesh, nvariables, nconstraints
using Nosy: BasicConverter
using Nosy: MassCarrier, EnergyCarrier
using Nosy: mass, energy
using Nosy: Component, Node, connect!, apply_constraints!
using Nosy: Snapshot, components, nodes, connect!

using JuMP: Model, AffExpr

@testset "Node constraints" begin


    tsim() = Sim(TimeMesh(fill(1//2, 10)), Model())

    function makecomp(name, mc, ec, vbehavior=[])   
        d = BasicConverter(mc, ec)
        c = Component(name, d, vbehavior)
        return c
    end


    # default node rule
    let s = tsim()

        mc = MassCarrier("m", s, energy=[1,2,3,4,5])
        ec = EnergyCarrier("e", s)

        n = Node("n", mc, rule=:default)
        c1 = makecomp("c1", mc, ec)
        c2 = makecomp("c2", ec, mc)
        sn = Snapshot(s)

        connect!(sn, c1, n)
        connect!(sn, c2, n)

        @test nvariables(s) == 20 # 2 time series
        @test nconstraints(s) == 20 # 2x lower bounds of time series

        apply_constraints!(n)

        @test nvariables(s) == 20 # no variables added
        @test nconstraints(s) == 30 # 1 new constraint for each timesteps

    end


    # curtailed node
    let s = tsim()

        mc = MassCarrier("m", s, energy=[1,2,3,4,5])
        ec = EnergyCarrier("e", s)

        n = Node("n", ec, rule=:curtailed)
        c1 = makecomp("c1", mc, ec)
        c2 = makecomp("c2", ec, mc)
        sn = Snapshot(s)

        connect!(sn, c1, n)
        connect!(sn, c2, n)

        @test nvariables(s) == 20 # 2 time series
        @test nconstraints(s) == 20 # 2x lower bounds of time series

        apply_constraints!(n)

        @test nvariables(s) == 20 # no variables added
        @test nconstraints(s) == 30 # 1 new constraint for each timesteps

    end


end
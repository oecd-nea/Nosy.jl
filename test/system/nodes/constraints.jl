using Nosy: Sim, TimeMesh, nvariables, nconstraints
using Nosy: BasicConverter, DispatchableSource, Demand
using Nosy: MassCarrier, EnergyCarrier
using Nosy: Component, Node, connect!, apply_constraints!
using Nosy: Snapshot
using Nosy: mass

using JuMP: Model
using Test

@testset "Node constraints" begin


    tsim() = Sim(Model(), mesh=TimeMesh(fill(1//2, 10)))

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

    # node balance on a coarser mesh
    let s = Sim(Model(), mesh=TimeMesh(fill(1//1, 4)))

        fine = s.mesh
        coarse = TimeMesh(fill(2//1, 2))
        mc = MassCarrier("m", s)

        n = Node("n", mc, mesh=coarse)
        src = Component("src", DispatchableSource(mc; mesh=fine))
        cons = Component("cons", Demand(mc, [10.0, 10.0]; modifier=mass, mesh=coarse))
        sn = Snapshot(s)

        connect!(sn, src, n)
        connect!(sn, cons, n)

        @test nvariables(s) == 4
        @test nconstraints(s) == 4

        apply_constraints!(n)

        @test nvariables(s) == 4
        @test nconstraints(s) == 6

    end

    # cross-mesh node balances require aligned boundaries
    let s = Sim(Model(), mesh=TimeMesh(fill(1//1, 4)))

        mc = MassCarrier("m", s)
        badmesh = TimeMesh([3//2, 5//2])

        @test_throws ArgumentError Node("n", mc, mesh=badmesh)

    end


end

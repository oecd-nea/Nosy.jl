using Nosy: MassCarrier
using Nosy: mass, energy, co2
using Nosy: Stepwise
using Nosy: Sim, TimeMesh
using Nosy: Port
using Nosy: PortStructure, addinput!, addoutput!
using Nosy: Node
using Nosy: DualPrice
using Nosy: _flow, flow

using JuMP: Model, AffExpr
using Test

@testset "Node flow" begin

    
    tsim() = Sim(Model(), mesh=TimeMesh(fill(1//2, 10)))

    function makeport_m(s::Sim)
        m = MassCarrier("m", s, energy=0.5)
        v = Stepwise([Float64(i) for i in 1:10], s.mesh)
        return Port(m, v)
    end

    # all ports must have the same carrier for a node
    function makenode(s::Sim)
        p1 = makeport_m(s)
        p2 = makeport_m(s)
        p3 = makeport_m(s)
        ps = PortStructure{AffExpr}(s)
        addinput!(ps, "p1", "n", p1)
        addinput!(ps, "p2", "n", p2)
        addoutput!(ps, "p3", "n", p3)
        return Node("n", p1.carrier, ps, 0., :default, false, DualPrice{AffExpr}(nothing), Symbol[]) # not usual constructor, to avoid connection stage
    end

    let s = tsim()

        n = makenode(s)

        # flow at a given step

        @test all((_flow(n, "p1", mass, step) for step in 1:10) .== 1:10)
        @test all((_flow(n, "p1", energy, step) for step in 1:10) .== (1:10) * 0.5)
        
        @test_throws AssertionError _flow(n, "p1", co2, 1) # CO2 modifier not compatible
        
        @test_throws AssertionError _flow(n, "p4", mass, 1) # no port named "p4"

        @test all((_flow(n, :input, mass, step) for step in 1:10) .== (1:10) * 2)
        @test all((_flow(n, :output, mass, step) for step in 1:10) .== (1:10) * 1)

        @test all((_flow(n, :input, energy, step) for step in 1:10) .== (1:10) * 2 * 0.5)
        @test all((_flow(n, :output, energy, step) for step in 1:10) .== (1:10) * 1 * 0.5)

        @test all(iszero(_flow(n, :output, co2, step)) for step in 1:10) # CO2 modifier not compatible


        # flow at a given hour

        @test all((flow(n, "p1", mass, h) for h in 0:4) .== 1:2:10)
        @test all((flow(n, "p1", energy, h) for h in 0:4) .== (1:2:10) * 0.5)
        
        @test_throws AssertionError flow(n, "p1", co2, 1) # CO2 modifier not compatible

        @test_throws AssertionError flow(n, "p4", mass, 1) # no port named "p4"

        @test all((flow(n, :input, mass, h) for h in 0:4) .== (1:2:10) * 2)
        @test all((flow(n, :output, mass, h) for h in 0:4) .== (1:2:10) * 1)

        @test all((flow(n, :input, energy, h) for h in 0:4) .== (1:2:10) * 2 * 0.5)
        @test all((flow(n, :output, energy, h) for h in 0:4) .== (1:2:10) * 1 * 0.5)

        @test all(iszero(flow(n, :output, co2, h)) for h in 0:4) # CO2 modifier not compatible

    end


    function makeport_m2(s::Sim)
        m = MassCarrier("m", s, energy=1:10) # mass to energy ratio is not constant
        v = Stepwise([Float64(i) for i in 1:10], s.mesh)
        return Port(m, v)
    end

    function makenode2(s::Sim)
        p1 = makeport_m2(s)
        p2 = makeport_m2(s)
        p3 = makeport_m2(s)
        ps = PortStructure{AffExpr}(s)
        addinput!(ps, "p1", "n", p1)
        addinput!(ps, "p2", "n", p2)
        addoutput!(ps, "p3", "n", p3)
        return Node("n", p1.carrier, ps, 0., :default, false, DualPrice{AffExpr}(nothing), Symbol[])
    end

    # test case where carrier mass to energy ratio is not constant
    # tests focused on cases involving getting the carrier modifier at a given step
    let s = tsim()

        n = makenode2(s)

        # flow at a given step

        @test all((_flow(n, "p1", energy, step) for step in 1:10) .== ((1:10) .* (1:10)))
        
        @test all((_flow(n, :input, energy, step) for step in 1:10) .== ((1:10) .* 2 .* (1:10)))
        @test all((_flow(n, :output, energy, step) for step in 1:10) .== ((1:10) .* 1 .* (1:10)))

        # flow at a given hour

        @test all((flow(n, "p1", energy, h) for h in 0:4) .== ((1:2:10) .* (1:2:10)))

        @test all((flow(n, :input, energy, h) for h in 0:4) .== ((1:2:10) .* 2 .* (1:2:10)))
        @test all((flow(n, :output, energy, h) for h in 0:4) .== ((1:2:10) .* 1 .* (1:2:10)))

    end

end

using Nosy: MassCarrier
using Nosy: Stepwise
using Nosy: Sim, TimeMesh
using Nosy: Port
using Nosy: PortStructure, addinput!, addlevel!
using Nosy: Node, _input, name, carrier, rule, iscurtailed
using Nosy: dualprice

using JuMP: Model, AffExpr
using ArgCheck: ArgumentError

@testset "Node" begin

    tsim() = Sim(TimeMesh(fill(1//2, 10)), Model())

    function makeport(s::Sim)
        m = MassCarrier("m", s)
        v = Stepwise([Float64(i) for i in 1:10], s.mesh)
        return Port(m, v)
    end

    let s = tsim()

        p1 = makeport(s)
        p2 = makeport(s)

        n = Node("n", p1.carrier)
        
        @test name(n) == "n"
        @test carrier(n) == p1.carrier
        @test rule(n) == :default
        @test !iscurtailed(n) 

        addinput!(n, "p1", p1)
        @test _input(n)["p1"] == p1

        # wrong carrier
        @test_throws AssertionError addinput!(n, "p2", p2)
        
        # nodes don't have a level
        @test_throws AssertionError addlevel!(n, "p1", p1)
        @test_throws AssertionError addlevel!(n, "p2", p2)

        # model not optimized
        @test_throws AssertionError dualprice(n)

    end


    let s = tsim()

        p1 = makeport(s)

        n = Node("n", p1.carrier, rule=:curtailed)
        
        @test rule(n) == :curtailed
        @test iscurtailed(n) 

    end


    let s = tsim()

        p1 = makeport(s)

        # wrong rule
        @test_throws ArgumentError Node("n", p1.carrier, rule=:wrong)
        
    end


end
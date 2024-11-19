using POSY2: MassCarrier
using POSY2: Stepwise
using POSY2: Sim, TimeMesh
using POSY2: Port
using POSY2: PortStructure, addinput!, addoutput!, addlevel!
using POSY2: Node, input, output, name, carrier, rule, iscurtailed
using JuMP: Model, AffExpr

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
        @test input(n)["p1"] == p1

        # wrong carrier
        @test_throws AssertionError addinput!(n, "p2", p2)
        
        # nodes don't have a level
        @test_throws AssertionError addlevel!(n, "p1", p1)
        @test_throws AssertionError addlevel!(n, "p2", p2)

    end


    let s = tsim()

        p1 = makeport(s)

        n = Node("n", p1.carrier, rule=:curtailed)
        
        @test rule(n) == :curtailed
        @test iscurtailed(n) 

    end


end
using Nosy: MassCarrier, EnergyCarrier
using Nosy: Stepwise
using Nosy: Sim, TimeMesh
using Nosy: Port, hasport
using Nosy: PortStructure, addinput!, addoutput!, addlevel!, addlosses!, hasoutput
using Nosy: Node, _input, _output, name, carrier, rule, iscurtailed
using Nosy: dualprice
using Nosy: balance, energy

using JuMP: Model, GenericAffExpr
using ArgCheck: ArgumentError

@testset "Node" begin

    tsim() = Sim(Model(), mesh=TimeMesh(fill(1//2, 10)))

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

        @test !haskey(_output(n), "losses") # no losses defined for this node

        addinput!(n, "p1", p1)
        @test _input(n)["p1"] == p1

        # wrong carrier
        @test_throws ArgumentError addinput!(n, "p2", p2)
        
        # nodes don't have a level
        @test_throws ArgumentError addlevel!(n, "p1", p1)
        @test_throws ArgumentError addlevel!(n, "p2", p2)

        # model not optimized
        @test_throws ArgumentError dualprice(n)

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

    # adding losses to the node
    let s = tsim()

        ec = EnergyCarrier("ec", s)

        p1 = Port(ec, Float64.(1:10))
        p2 = Port(ec, Float64.(11:20))
        p3 = Port(ec, Float64.(21:30))

        n = Node("n", p1.carrier, rule=:default, losses=0.3) # 30% losses

        addinput!(n, "p1", p1)
        addinput!(n, "p2", p2)
        addoutput!(n, "p3", p3)

        # next function must be called during Snapshot finalization
        # we didn't build a Snapshot so we call it manually instead
        addlosses!(n)

        @test hasoutput(n.s, "losses")
        
        @test all(balance(n, :output, energy, collapse=false, aggregate=false)["losses"] .== 0.3 * balance(n, :input, energy, collapse=false, aggregate=true))
        
    end

end
using Nosy: MassCarrier, EnergyCarrier, CO2Carrier
using Nosy: mass, energy, co2
using Nosy: Stepwise
using Nosy: Sim, TimeMesh
using Nosy: Port
using Nosy: PortStructure, addinput!, addoutput!, addlevel!
using Nosy: balance

using JuMP: Model, AffExpr

@testset "Node balance" begin

    
    tsim() = Sim(TimeMesh(fill(1//2, 10)), Model())

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
        addinput!(ps, "p1", p1)
        addinput!(ps, "p2", p2)
        addoutput!(ps, "p3", p3)
        return (Node("n", p1.carrier, ps, :default, false, Nosy.DualPrice{AffExpr}(nothing)), p1, p2, p3)
    end

    let s = tsim()

        # tests on input of port structure only
        (n, p1, p2, p3) = makenode(s)

        # non-collapsed, non-aggregated balance
        b = balance(n, :input, mass, collapse=false, aggregate=false)
        @test haskey(b, "p1") && b["p1"] == mass(p1)
        @test haskey(b, "p2") && b["p2"] == mass(p2)    
        @test !haskey(b, "p3")
        @test_throws ArgumentError balance(n, :level, mass, collapse=false, aggregate=false) # :level not allowed
    
    end

end
using Nosy: MassCarrier, EnergyCarrier, CO2Carrier
using Nosy: mass, energy, co2
using Nosy: Stepwise
using Nosy: Sim, TimeMesh
using Nosy: Port, Node
using Nosy: PortStructure, addinput!, addoutput!, addlevel!, PortRef
using Nosy: balance, _balance
using Nosy: DualPrice

using JuMP: Model, AffExpr

@testset "Node balance" begin

    
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
        addinput!(ps, "p1", "c", p1)
        addinput!(ps, "p2", "c", p2)
        addoutput!(ps, "p3", "c", p3)
        return (Node("n", p1.carrier, ps, 0., :default, false, DualPrice{AffExpr}(nothing), Symbol[]), p1, p2, p3)
    end

    let s = tsim()

        # tests on input of port structure only
        (n, p1, p2, p3) = makenode(s)

        # non-collapsed, non-aggregated balance
        b = _balance(n, :input, mass, collapse=false, aggregate=false)
        @test haskey(b, PortRef("c", "p1")) && b[PortRef("c", "p1")] == mass(p1)
        @test haskey(b, PortRef("c", "p2")) && b[PortRef("c", "p2")] == mass(p2)    
        @test !haskey(b, PortRef("c", "p3"))
        @test_throws ArgumentError balance(n, :level, mass, collapse=false, aggregate=false) # :level not allowed
    
    end

end
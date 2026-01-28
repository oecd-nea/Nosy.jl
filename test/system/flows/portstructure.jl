using Nosy: MassCarrier, EnergyCarrier
using Nosy: mass, energy, co2, defaultmodifier
using Nosy: Stepwise
using Nosy: Sim, TimeMesh
using Nosy: Port
using Nosy: PortStructure, addinput!
using Nosy: _flow

using JuMP: Model, AffExpr
using Test

@testset "Port structure flow" begin

    
    tsim() = Sim(Model(), mesh=TimeMesh(fill(1//2, 10)))

    function makeport_m(s::Sim)
        m = MassCarrier("m", s, energy=collect(1:10))
        v = Stepwise([Float64(i) for i in 1:10], s.mesh)
        return Port(m, v)
    end

    # NB this energy port also bears mass due to "energy" keyword
    function makeport_e(s::Sim)
        m = EnergyCarrier("e", s, energy=2.)
        v = Stepwise([Float64(i) for i in 1:10], s.mesh)
        return Port(m, v)
    end

    let s = tsim()

        # tests on input of port structure only
        p1 = makeport_m(s)
        p2 = makeport_e(s)
        ps = PortStructure{AffExpr}(s)
        addinput!(ps, "p1", "comp", p1)
        addinput!(ps, "p2", "comp", p2)

        @test all((_flow(ps, "p1", "comp", mass, step) for step in 1:10)  .== 1:10) # check default modifier (implicit)
        @test all((_flow(ps, "p2", "comp", energy, step) for step in 1:10)  .== 1:10) # check default modifier (implicit)

        @test all((_flow(ps, "p1", "comp", defaultmodifier, step) for step in 1:10)  .== 1:10) # check default modifier (implicit)
        @test all((_flow(ps, "p2", "comp", defaultmodifier, step) for step in 1:10)  .== 1:10) # check default modifier (implicit)

        @test all((_flow(ps, "p1", "comp", energy, step) for step in 1:10)  .== (1:10) .* (1:10)) # check non-default modifier
        @test all((_flow(ps, "p2", "comp", mass, step) for step in 1:10)  .== (1:10) / 2) # check non-default modifier

        @test_throws AssertionError _flow(ps, "p1", "comp", co2, 1) # port does not bear modifier
        
        @test _flow(ps, "p1", "comp", mass, 10+5) == _flow(ps, "p1", "comp", mass, 5) # test modulo is working

        @test_throws AssertionError _flow(ps, "p3", "comp", mass, 1) # port named p3 not present in ps

    end

end

using Nosy: MassCarrier, EnergyCarrier, CO2Carrier
using Nosy: mass, energy, co2
using Nosy: Stepwise
using Nosy: Sim, TimeMesh
using Nosy: Port
using Nosy: PortStructure, addinput!, addoutput!, addlevel!
using Nosy: _flow

using JuMP: Model, GenericAffExpr

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
        addinput!(ps, "p1", p1)
        addinput!(ps, "p2", p2)

        @test all((_flow(ps, "p1", mass, step) for step in 1:10)  .== 1:10) # check default modifier (implicit)
        @test all((_flow(ps, "p2", energy, step) for step in 1:10)  .== 1:10) # check default modifier (implicit)

        @test all((_flow(ps, "p1", defaultmodifier, step) for step in 1:10)  .== 1:10) # check default modifier (implicit)
        @test all((_flow(ps, "p2", defaultmodifier, step) for step in 1:10)  .== 1:10) # check default modifier (implicit)

        @test all((_flow(ps, "p1", energy, step) for step in 1:10)  .== (1:10) .* (1:10)) # check non-default modifier
        @test all((_flow(ps, "p2", mass, step) for step in 1:10)  .== (1:10) / 2) # check non-default modifier

        @test_throws AssertionError _flow(ps, "p1", co2, 1) # port does not bear modifier
        
        @test _flow(ps, "p1", mass, 10+5) == _flow(ps, "p1", mass, 5) # test modulo is working

        @test_throws AssertionError _flow(ps, "p3", mass, 1) # port named p3 not present in ps

    end

    let s = tsim()

        # Test port ambiguity management
        p1 = makeport_m(s)
        p2 = makeport_e(s)

        ps = PortStructure{AffExpr}(s)
        addinput!(ps, "p1", p1)
        addoutput!(ps, "p1", p2) # same name

        @test_throws AssertionError _flow(ps, "p1", mass, 1)

        @test all((_flow(ps, "p1", :input, energy, step) for step in (1:10)) .== (1:10) .* (1:10))
        @test all((_flow(ps, "p1", :output, energy, step) for step in (1:10)) .== 1:10)

    end

end
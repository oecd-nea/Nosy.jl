using Nosy: MassCarrier, EnergyCarrier, CO2Carrier
using Nosy: mass, energy, co2, defaultmodifier
using Nosy: Stepwise
using Nosy: Sim, TimeMesh
using Nosy: Port
using Nosy: _flow

using JuMP: Model, AffExpr

@testset "Port flow" begin

    
    tsim() = Sim(TimeMesh(fill(1//2, 10)), Model())

    function makeport_m(s::Sim)
        m = MassCarrier("m", s, energy=collect(1:10))
        v = Stepwise([Float64(i) for i in 1:10], s.mesh)
        return Port(m, v)
    end

    let s = tsim()

        p = makeport_m(s)

        # test flow at a given timestep
        @test all((_flow(p, mass, step) for step in 1:10)  .== 1:10) # check default modifier (implicit)

        @test all((_flow(p, defaultmodifier, step) for step in 1:10)  .== 1:10) # check default modifier (implicit)

        @test all((_flow(p, energy, step) for step in 1:10)  .== (1:10) .* (1:10)) # check non-default modifier

        @test_throws AssertionError _flow(p, co2, 1) # port does not bear modifier
        
        @test _flow(p, mass, 10+5) == _flow(p, mass, 5) # test modulo is working
    
    end

end
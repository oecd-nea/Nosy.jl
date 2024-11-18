using POSY2: MassCarrier, EnergyCarrier, CO2Carrier
using POSY2: Stepwise
using POSY2: defaultmodifier, mass, energy, co2
using POSY2: _defaultmodifier
using POSY2: Sim, TimeMesh, sim
using POSY2: Port, is_used, set_used!
using JuMP: Model, AffExpr



@testset "Port" begin

    tsim() = Sim(TimeMesh(fill(1//2, 10)), Model())

    let s = tsim()

        # testing port state
        m = MassCarrier("m", s)
        
        v = Stepwise([Float64(i) for i in 1:10], s.mesh)
        p = Port(m, v)

        @test p isa Port{AffExpr, MassCarrier}

        @test !is_used(p)
        set_used!(p)
        @test is_used(p)

    end


    let s = tsim()

        # mass carrier
        m = MassCarrier("m", s)
        
        # Stepwise{Float64}
        v = Stepwise([Float64(i) for i in 1:10], s.mesh)
        p = Port(m, v)

        @test all(p.series[i] == v[i] for i in 1:10)

    end


    let s = tsim()

        m = MassCarrier("m", s)
        
        # unit range & Stepwise length
        v = 1:10
        p = Port(m, v)

        @test all(p.series[i] == Float64(v[i]) for i in 1:10)

    end


    let s = tsim()

        m = MassCarrier("m", s)
        
        # Hourly
        v = Hourly([Float64(i) for i in 1:5], s.mesh)
        p = Port(m, v)

        @test all(p.series[i] == Stepwise(v, s.mesh)[i] for i in 1:10)

    end


    let s = tsim()

        m = MassCarrier("m", s)
        
        # unit range and Hourly length
        v = 1:5
        p = Port(m, v)

        @test all(p.series[i] == Stepwise(v, s.mesh)[i] for i in 1:10)

    end


    let s = tsim()

        # mass carrier
        m = MassCarrier("m", s)
        
        v = Stepwise([Float64(i) for i in 1:10], s.mesh)
        p = Port(m, v)

        @test all(mass(p)[i] == v[i] for i in 1:10)
        @test_throws AssertionError energy(p)
        @test_throws AssertionError co2(p)

        @test defaultmodifier(p) == mass(p)

    end


    let s = tsim()

        # mass carrier with energy data
        m = MassCarrier("m", s, energy = 2.)
        
        v = Stepwise([Float64(i) for i in 1:10], s.mesh)
        p = Port(m, v)

        @test all(mass(p)[i] == v[i] for i in 1:10)
        @test all(energy(p)[i] == 2. * v[i] for i in 1:10)
        @test_throws AssertionError co2(p)

        @test defaultmodifier(p) == mass(p)

    end


    let s = tsim()

        # energy carrier
        m = EnergyCarrier("m", s)
        
        v = Stepwise([Float64(i) for i in 1:10], s.mesh)
        p = Port(m, v)

        @test_throws AssertionError mass(p)
        @test all(energy(p)[i] == v[i] for i in 1:10)
        @test_throws AssertionError co2(p)

        @test defaultmodifier(p) == energy(p)

    end


    let s = tsim()

        # energy carrier with energy -> mass data
        m = EnergyCarrier("m", s, energy = 2.)
        
        v = Stepwise([Float64(i) for i in 1:10], s.mesh)
        p = Port(m, v)

        @test all(mass(p)[i] == v[i] / 2. for i in 1:10)
        @test all(energy(p)[i] == v[i] for i in 1:10)
        @test_throws AssertionError co2(p)

        @test defaultmodifier(p) == energy(p)

    end


    let s = tsim()

        # CO2 carrier with default CO2 weight
        m = CO2Carrier("m", s)
        
        v = Stepwise([Float64(i) for i in 1:10], s.mesh)
        p = Port(m, v)

        @test all(mass(p)[i] == v[i] for i in 1:10)
        @test_throws AssertionError energy(p)
        @test all(co2(p)[i] == v[i] for i in 1:10)

        @test defaultmodifier(p) == mass(p)

    end


    let s = tsim()

        # CO2 carrier with non-default CO2 weight
        m = CO2Carrier("m", s, weight=2.)
        
        v = Stepwise([Float64(i) for i in 1:10], s.mesh)
        p = Port(m, v)

        @test all(mass(p)[i] == v[i] for i in 1:10)
        @test_throws AssertionError energy(p)
        @test all(co2(p)[i] == 2. * v[i] for i in 1:10)

        @test defaultmodifier(p) == mass(p)

    end

end
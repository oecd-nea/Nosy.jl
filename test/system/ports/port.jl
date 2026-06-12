using Nosy: MassCarrier, EnergyCarrier, CO2Carrier
using Nosy: Stepwise
using Nosy: defaultmodifier, mass, energy, co2
using Nosy: Sim, TimeMesh
using Nosy: Port, is_used, set_used!, hasmodifier
using Nosy: remesh
using JuMP: Model, AffExpr
using Test



@testset "Port" begin

    tsim() = Sim(Model(), mesh=TimeMesh(fill(1//2, 10)))

    let s = tsim()

        # testing port state
        m = MassCarrier("m", s)
        
        v = Stepwise([Float64(i) for i in 1:10], s.mesh)
        p = Port(m, v)

        @test p isa Port{AffExpr, MassCarrier}

        @test !is_used(p)
        set_used!(p)
        @test is_used(p)

        @test hasmodifier(p, mass)
        @test !hasmodifier(p, energy)
        @test !hasmodifier(p, co2)

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


    let s = Sim(Model(), mesh=TimeMesh(fill(1//2, 4)))

        # carrier modifiers are continuous and projected to the port mesh
        coarse = TimeMesh(fill(1//1, 2))
        m = MassCarrier("m", s, energy=[1.0, 3.0, 5.0, 7.0])
        v = Stepwise([10.0, 20.0], coarse)
        p = Port(m, v)
        modifier = remesh(energy(m), coarse)

        @test modifier.data == [3.0, 5.0]
        @test all(energy(p)[i] == modifier[i] * v[i] for i in 1:2)

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

        @test !hasmodifier(p, mass)
        @test hasmodifier(p, energy)
        @test !hasmodifier(p, co2)

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

        @test hasmodifier(p, mass)
        @test hasmodifier(p, energy)
        @test !hasmodifier(p, co2)

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

        @test hasmodifier(p, mass)
        @test !hasmodifier(p, energy)
        @test hasmodifier(p, co2)

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


    let s = tsim()

        m = MassCarrier("m", s)

        @test_throws MethodError Port(m, Float64.(1:10))

    end

end

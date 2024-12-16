using Nosy: MassCarrier, EnergyCarrier, CO2Carrier
using Nosy: carrierstyle
using Nosy: defaultmodifier, mass, energy, co2
using Nosy: Sim, TimeMesh, sim
using Nosy: eachhour, eachstep
using JuMP: Model

@testset "Carriers" begin

    tsim() = Sim(TimeMesh(fill(1//2, 10)), Model())
    
    let s = tsim()

        # mass carrier

        m1 = MassCarrier("m1", s)
        @test sim(m1) === s

        m2 = MassCarrier("m2", s)
        @test m1 != m2
        
        @test all(mass(m1) .== defaultmodifier(m1))
        @test isnothing(energy(m1))
        @test all(mass(m1)[i] == 1. for i in eachstep(s))
        @test isnothing(co2(m1))

        m3 = MassCarrier("m3", s, energy=2.)
        @test all(mass(m3) .== defaultmodifier(m3))
        @test all(energy(m3)[i] == 2. for i in eachstep(s))
        @test all(mass(m3)[i] == 1. for i in eachstep(s)) 
        @test isnothing(co2(m3))

        m4 = MassCarrier("m4", s, energy=Float64.(1:10))
        @test all(mass(m4) .== defaultmodifier(m4))
        @test all(energy(m4)[i] == Float64(i) for i in eachstep(s))
        @test all(mass(m4)[i] == 1. for i in eachstep(s)) 
        @test isnothing(co2(m4))

        m5 = MassCarrier("m5", s, energy=2) # note the integer argument
        @test all(energy(m5)[i] == 2. for i in eachstep(s)) # Float64 

        m6 = MassCarrier("m6", s, energy=1:10) # note the integer argument
        @test all(energy(m6)[i] == Float64(i) for i in eachstep(s))

    end


    let s = tsim()

        # energy carrier
        
        e1 = EnergyCarrier("e1", s)
        @test sim(e1) === s

        e2 = EnergyCarrier("e2", s)
        @test e1 != e2
        
        @test all(energy(e1) .== defaultmodifier(e1))
        @test all(energy(e1)[i] == 1. for i in eachstep(s))
        @test isnothing(mass(e1))
        @test isnothing(co2(e1))

        e3 = EnergyCarrier("e3", s, energy=2.)
        @test all(energy(e3) .== defaultmodifier(e3))
        @test all(energy(e3)[i] == 1. for i in eachstep(s))
        @test all(mass(e3)[i] == 1/2. for i in eachstep(s))
        @test isnothing(co2(e3))

        e4 = EnergyCarrier("e4", s, energy=Float64.(1:10))
        @test all(energy(e4) .== defaultmodifier(e4))
        @test all(energy(e4)[i] == 1. for i in eachstep(s)) 
        @test all(mass(e4)[i] == 1 / Float64(i) for i in eachstep(s))
        @test isnothing(co2(e4))

        @test_throws ArgumentError EnergyCarrier("e", s, energy=[1., 2.]) # wrong number of steps

        e5 = EnergyCarrier("e5", s, energy=2) # note the integer argument
        @test all(mass(e5)[i] == 1/2. for i in eachstep(s))

        e6 = EnergyCarrier("e6", s, energy=1:10) # note the integer argument
        @test all(mass(e6)[i] == 1 / Float64(i) for i in eachstep(s))
    end


    let s = tsim()

        # CO2 carrier

        c1 = CO2Carrier("c1", s)
        @test sim(c1) === s

        c2 = CO2Carrier("c2", s)
        @test c1 != c2
        
        @test all(mass(c1) .== defaultmodifier(c1))
        @test isnothing(energy(c1))
        @test all(mass(c1)[i] == 1. for i in eachstep(s))
        @test all(mass(c1)[i] == 1. for i in eachstep(s))

        c3 = CO2Carrier("c3", s, weight=2.)
        @test all(mass(c3) .== defaultmodifier(c3))
        @test isnothing(energy(c1))
        @test all(mass(c3)[i] == 1. for i in eachstep(s)) 
        @test all(co2(c3)[i] == 2. for i in eachstep(s)) 

        @test_throws TypeError CO2Carrier("c4", s, weight=Float64.(1:10))
        @test_throws MethodError CO2Carrier("c4", s, energy=1.)
        @test_throws MethodError CO2Carrier("c4", s, energy=Float64.(1:10))

        c4 = CO2Carrier("c4", s, weight=2) # integer argument
        @test all(co2(c4)[i] == 2. for i in eachstep(s)) 
    end

end
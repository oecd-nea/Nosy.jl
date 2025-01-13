using Nosy: MassCarrier, EnergyCarrier
using Nosy: mass, energy
using Nosy: Sim, TimeMesh, sim
using Nosy: Stepwise
using Nosy: getport, hasinput, hasoutput
using Nosy: build
using Nosy: ProfileSource, ProfileSourceModel

using JuMP: Model

@testset "ProfileSource" begin

    tsim() = Sim(Model(), mesh=TimeMesh(fill(1//2, 10)))


    let profile = collect(1:10) / 10 # ~stepwise profile

        s = tsim()
        mc = MassCarrier("m", s, energy=[1,2,3,4,5])

        d = ProfileSource(mc, profile)        

        m = build(d, "profile")

        @test !hasinput(m, "input")
        @test hasoutput(m, "output")

        @test !hasport(m, "input")
        @test hasport(m, "output")
        @test !hasport(m, "level")

        @test m.cap isa AffExpr
        @test all(mass(getport(m, "output")) .== m.cap * profile) # hidden capacity is applied to default modifier

        @test sim(m) == s

        @test carrier(getport(m, "output")) == mc

    end


    let profile = collect(1:5) / 5 # ~hourly profile

        s = tsim()
        mc = MassCarrier("m", s, energy=[1,2,3,4,5])

        d = ProfileSource(mc, profile)        

        m = build(d, "profile")

        @test !hasinput(m, "input")
        @test hasoutput(m, "output")

        @test !hasport(m, "input")
        @test hasport(m, "output")
        @test !hasport(m, "level")

        @test m.cap isa AffExpr
        @test all(mass(getport(m, "output")) .== m.cap * Stepwise(profile, s.mesh)) # hidden capacity is applied to default modifier

        @test sim(m) == s

        @test carrier(getport(m, "output")) == mc

    end


    let profile = 0.5 # flat profile

        s = tsim()
        mc = MassCarrier("m", s, energy=[1,2,3,4,5])

        d = ProfileSource(mc, profile)        

        m = build(d, "profile")

        @test all(mass(getport(m, "output")) .== m.cap * profile) # hidden capacity is applied to default modifier

    end


    let s = tsim(), mc = MassCarrier("m", s, energy=[1,2,3,4,5])

        @test_throws ArgumentError ProfileSource(mc, [0.1, 0.2, 0.3]) # profile doesn't match hourly / stepwise / scalar
        
        @test_throws ArgumentError ProfileSource(mc, [-0.1, 0.2, 0.3, 0.4, 0.5]) # profile has a negative value
        
        @test_throws ArgumentError ProfileSource(mc, [0.1, 0.2, 0.3, 0.4, 1.5]) # profile has a value > 1

    end
    

end
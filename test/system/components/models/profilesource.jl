using Nosy: MassCarrier, EnergyCarrier, carrier
using Nosy: mass, energy
using Nosy: Sim, TimeMesh, sim
using Nosy: Stepwise
using Nosy: _getport, _hasinput, _hasoutput, hasport
using Nosy: build
using Nosy: ProfileSource, ProfileSourceModel, _profile

using JuMP: Model, AffExpr

@testset "ProfileSource" begin

    tsim() = Sim(Model(), mesh=TimeMesh(fill(1//2, 10)))


    let profile = collect(1:10) / 10 # ~stepwise profile

        s = tsim()
        mc = MassCarrier("m", s, energy=[1,2,3,4,5])

        d = ProfileSource(mc, profile)        

        m = build(d, "profile")

        @test !_hasinput(m.s, "input", "profile")
        @test _hasoutput(m.s, "output", "profile")

        @test !hasport(m.s, "input", "profile")
        @test hasport(m.s, "output", "profile")
        @test !hasport(m.s, "level", "profile")

        @test all(_profile(m) .== profile)

        @test sim(m) == s

        @test carrier(_getport(m.s, "output", "profile")) == mc

    end


    let profile = collect(1:5) / 5 # ~hourly profile

        s = tsim()
        mc = MassCarrier("m", s, energy=[1,2,3,4,5])

        d = ProfileSource(mc, profile)        

        m = build(d, "profile")

        @test !_hasinput(m.s, "input", "profile")
        @test _hasoutput(m.s, "output", "profile")

        @test !hasport(m.s, "input", "profile")
        @test hasport(m.s, "output", "profile")
        @test !hasport(m.s, "level", "profile")

        @test all(_profile(m) .== Stepwise(profile, s.mesh))

        @test sim(m) == s

        @test carrier(_getport(m.s, "output", "profile")) == mc

    end


    let profile = 0.5 # flat profile

        s = tsim()
        mc = MassCarrier("m", s, energy=[1,2,3,4,5])

        d = ProfileSource(mc, profile)        

        m = build(d, "profile")

        @test all(_profile(m) .==  profile)

    end


    let s = tsim(), mc = MassCarrier("m", s, energy=[1,2,3,4,5])

        @test_throws ArgumentError ProfileSource(mc, [0.1, 0.2, 0.3]) # profile doesn't match hourly / stepwise / scalar
        
        @test_throws ArgumentError ProfileSource(mc, [-0.1, 0.2, 0.3, 0.4, 0.5]) # profile has a negative value
        
        # test that a warning is generated
        @test (@test_logs (:warn, "Some profiles have values superior to 1 and there is no cutoff") ProfileSource(mc, [0.1, 0.2, 0.3, 0.4, 1.5])) isa ProfileSource # profile has a value > 1

    end
    
    let profile = collect(1:10) / 5 # ~stepwise profile, some values are > 1

        s = tsim()
        mc = MassCarrier("m", s, energy=[1,2,3,4,5])

        d = ProfileSource(mc, profile, cutoff=1.)

        m = build(d, "profile")

        @test all(_profile(m) .== [0.2, 0.4, 0.6, 0.8, 1., 1., 1., 1., 1., 1.]) # checking cutoff

    end

end
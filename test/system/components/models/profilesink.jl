using Nosy: MassCarrier, carrier
using Nosy: Sim, TimeMesh, sim
using Nosy: Stepwise
using Nosy: _getport, _hasinput, _hasoutput, hasport
using Nosy: build
using Nosy: ProfileSink, _profile
using Nosy: Component, FixedCapacity, VariableCapacity, energy, mass
using Nosy: nvariables, nconstraints

using JuMP: Model
using Test

@testset "ProfileSink" begin

    tsim() = Sim(Model(), mesh=TimeMesh(fill(1//2, 10)))

    let profile = collect(1:10) / 10

        s = tsim()
        mc = MassCarrier("m", s, energy=[1,2,3,4,5])

        d = ProfileSink(mc, profile)
        m = build(d, "profile")

        @test _hasinput(m.s, "input", "profile")
        @test !_hasoutput(m.s, "output", "profile")

        @test hasport(m.s, "input", "profile")
        @test !hasport(m.s, "output", "profile")
        @test !hasport(m.s, "level", "profile")

        @test all(_profile(m) .== profile)
        @test sim(m) == s
        @test carrier(_getport(m.s, "input", "profile")) == mc

    end

    let profile = collect(1:5) / 5

        s = tsim()
        mc = MassCarrier("m", s, energy=[1,2,3,4,5])

        d = ProfileSink(mc, profile)
        m = build(d, "profile")

        @test all(_profile(m) .== Stepwise(profile, s.mesh))

    end

    let s = tsim(), mc = MassCarrier("m", s, energy=[1,2,3,4,5])

        @test_throws ArgumentError ProfileSink(mc, [0.1, 0.2, 0.3])
        @test_throws ArgumentError ProfileSink(mc, [-0.1, 0.2, 0.3, 0.4, 0.5])
        @test (@test_logs (:warn, "Some profiles have values superior to 1 and there is no cutoff") ProfileSink(mc, [0.1, 0.2, 0.3, 0.4, 1.5])) isa ProfileSink

    end

    let profile = collect(1:10) / 5

        s = tsim()
        mc = MassCarrier("m", s, energy=[1,2,3,4,5])

        d = ProfileSink(mc, profile, cutoff=1.0)
        m = build(d, "profile")

        @test all(_profile(m) .== [0.2, 0.4, 0.6, 0.8, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0])

    end

    let s = tsim(), mc = MassCarrier("m", s, energy=[1,2,3,4,5])

        c = Component("profile", ProfileSink(mc, collect(1:10) / 10), [FixedCapacity("input", mass, 5.0)])
        flow = mass(_getport(c.s, "input", "profile"))

        @test all(flow .== collect(0.5:0.5:5.0))
        @test nvariables(sim(c)) == 0
        @test nconstraints(sim(c)) == 0

    end

    let s = tsim(), mc = MassCarrier("m", s, energy=[1,2,3,4,5])

        c = Component("profile", ProfileSink(mc, collect(1:10) / 10), [VariableCapacity("input", mass)])

        @test nvariables(sim(c)) == 1
        @test nconstraints(sim(c)) == 1

    end

    let s = tsim(), mc = MassCarrier("m", s, energy=[1,2,3,4,5])

        @test_throws AssertionError Component("profile", ProfileSink(mc, 1.0))
        @test_throws ArgumentError Component("profile", ProfileSink(mc, 1.0), [FixedCapacity("input", energy, 5.0)])

    end

end

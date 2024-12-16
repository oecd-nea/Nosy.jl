using Nosy: MassCarrier, EnergyCarrier
using Nosy: mass, energy
using Nosy: Sim, TimeMesh
using Nosy: getport, hasinput, hasoutput
using Nosy: build
using Nosy: BasicConverter, BasicConverterModel

using JuMP: Model
using ArgCheck: ArgumentError

@testset "BasicConverter" begin

    tsim() = Sim(TimeMesh(fill(1//2, 10)), Model())

    # energy modifier, scalar ratio
    let s = tsim()

        mc = MassCarrier("m", s, energy=[1,2,3,4,5])
        ec = EnergyCarrier("e", s)

        c = BasicConverter(
            mc,
            ec,
            ratio = 0.5,
            modifier = energy
        )        

        m = build(c, "conv")

        @test hasinput(m, "input")
        @test hasoutput(m, "output")

        @test hasport(m, "input")
        @test hasport(m, "output")
        @test !hasport(m, "level")

        @test sim(m) == s

        @test carrier(getport(m, "input")) == mc
        @test carrier(getport(m, "output")) == ec

        @test all(energy(getport(m, "output")) .== 0.5 .* energy(getport(m, "input")))

    end

    # default modifier, Hourly-like ratio
    let s = tsim()

        mc = MassCarrier("m", s, energy=[1,2,3,4,5])
        ec = EnergyCarrier("e", s)

        c = BasicConverter(
            mc,
            ec,
            ratio = [1,2,3,4,5],
            # no modifier -> default modifier
        )        

        m = build(c, "conv")

        @test all(energy(getport(m, "output")) .== Stepwise([1,2,3,4,5], s.mesh) .* mass(getport(m, "input")))

    end

    # default modifier, Stepwise-like ratio
    let s = tsim()

        mc = MassCarrier("m", s, energy=[1,2,3,4,5])
        ec = EnergyCarrier("e", s)

        c = BasicConverter(
            mc,
            ec,
            ratio = [1,2,3,4,5,6,7,8,9,10],
            # no modifier -> default modifier
        )        

        m = build(c, "conv")

        @test all(energy(getport(m, "output")) .== Stepwise([1,2,3,4,5,6,7,8,9,10], s.mesh) .* mass(getport(m, "input")))

    end

    # incompatible modifier
    let s = tsim()

        mc = MassCarrier("m", s, energy=[1,2,3,4,5])
        ec = EnergyCarrier("e", s)

        @test_throws ArgumentError BasicConverter(
            mc,
            ec,
            ratio = 0.5,
            modifier = mass # not compatible with ec
        )        

    end

end
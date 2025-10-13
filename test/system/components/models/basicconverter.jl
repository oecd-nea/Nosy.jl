using Nosy: Stepwise
using Nosy: MassCarrier, EnergyCarrier
using Nosy: mass, energy, carrier
using Nosy: Sim, TimeMesh
using Nosy: _getport, _hasinput, _hasoutput, hasport
using Nosy: build
using Nosy: BasicConverter, BasicConverterModel

using JuMP: Model
using ArgCheck: ArgumentError
using Test

@testset "BasicConverter" begin

    tsim() = Sim(Model(), mesh=TimeMesh(fill(1//2, 10)))

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

        @test _hasinput(m.s, "input", "conv")
        @test _hasoutput(m.s, "output", "conv")

        @test hasport(m.s, "input", "conv")
        @test hasport(m.s, "output", "conv")
        @test !hasport(m.s, "level", "conv")

        @test sim(m) == s

        @test carrier(_getport(m.s, "input", "conv")) == mc
        @test carrier(_getport(m.s, "output", "conv")) == ec

        @test all(energy(_getport(m.s, "output", "conv")) .== 0.5 .* energy(_getport(m.s, "input", "conv")))

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

        @test all(energy(_getport(m.s, "output", "conv")) .== Stepwise([1,2,3,4,5], s.mesh) .* mass(_getport(m.s, "input", "conv")))

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

        @test all(energy(_getport(m.s, "output", "conv")) .== Stepwise([1,2,3,4,5,6,7,8,9,10], s.mesh) .* mass(_getport(m.s, "input", "conv")))

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
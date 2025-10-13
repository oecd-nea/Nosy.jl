using Nosy: MassCarrier, EnergyCarrier
using Nosy: mass, energy
using Nosy: Sim, TimeMesh, sim
using Nosy: Stepwise
using Nosy: _getport, _hasinput, _hasoutput
using Nosy: build
using Nosy: Demand, DemandModel

using JuMP: Model, AffExpr

@testset "Demand" begin

    tsim() = Sim(Model(), mesh=TimeMesh(fill(1//2, 10)))

    # ~stepwise profile, no modifier
    let series = collect(1:10)

        s = tsim()
        mc = MassCarrier("m", s, energy=[1,2,3,4,5])

        d = Demand(mc, series)

        m = build(d, "demand")

        @test _hasinput(m.s, "input", "demand")
        @test !_hasoutput(m.s, "output", "demand")

        @test hasport(m.s, "input", "demand")
        @test !hasport(m.s, "output", "demand")
        @test !hasport(m.s, "level", "demand")

        @test all(mass(_getport(m.s, "input", "demand")) .== series)

        @test sim(m) == s

        @test carrier(_getport(m.s, "input", "demand")) == mc

    end

    # ~stepwise profile, energy modifier
    let series = collect(1:10)

        s = tsim()
        mc = MassCarrier("m", s, energy=[1,2,3,4,5])

        d = Demand(mc, series, modifier=energy)

        m = build(d, "demand")

        @test all(isapprox.(energy(_getport(m.s, "input", "demand")), AffExpr.(series)))

        @test carrier(_getport(m.s, "input", "demand")) == mc

    end


    # ~hourly profile, no modifier
    let series = collect(1:5)

        s = tsim()
        mc = MassCarrier("m", s, energy=[1,2,3,4,5])

        d = Demand(mc, series)

        m = build(d, "demand")

        @test all(mass(_getport(m.s, "input", "demand")) .== Stepwise(series, s.mesh))

    end


    # scalar profile, no modifier
    let series = 5

        s = tsim()
        mc = MassCarrier("m", s, energy=[1,2,3,4,5])

        d = Demand(mc, series)

        m = build(d, "demand")

        @test all(mass(_getport(m.s, "input", "demand")) .== Stepwise(series, s.mesh))

    end

end
using Nosy: MassCarrier, EnergyCarrier
using Nosy: mass, energy
using Nosy: Sim, TimeMesh, sim
using Nosy: Stepwise
using Nosy: getport, hasinput, hasoutput
using Nosy: build
using Nosy: Demand, DemandModel

using JuMP: Model

@testset "Demand" begin

    tsim() = Sim(Model(), mesh=TimeMesh(fill(1//2, 10)))

    # ~stepwise profile, no modifier
    let series = collect(1:10)

        s = tsim()
        mc = MassCarrier("m", s, energy=[1,2,3,4,5])

        d = Demand(mc, series)

        m = build(d, "demand")

        @test hasinput(m, "input")
        @test !hasoutput(m, "output")

        @test hasport(m, "input")
        @test !hasport(m, "output")
        @test !hasport(m, "level")

        @test all(mass(getport(m, "input")) .== series)

        @test sim(m) == s

        @test carrier(getport(m, "input")) == mc

    end

    # ~stepwise profile, energy modifier
    let series = collect(1:10)

        s = tsim()
        mc = MassCarrier("m", s, energy=[1,2,3,4,5])

        d = Demand(mc, series, modifier=energy)

        m = build(d, "demand")

        @test all(isapprox.(energy(getport(m, "input")), AffExpr.(series)))

        @test carrier(getport(m, "input")) == mc

    end


    # ~hourly profile, no modifier
    let series = collect(1:5)

        s = tsim()
        mc = MassCarrier("m", s, energy=[1,2,3,4,5])

        d = Demand(mc, series)

        m = build(d, "demand")

        @test all(mass(getport(m, "input")) .== Stepwise(series, s.mesh))

    end


    # scalar profile, no modifier
    let series = 5

        s = tsim()
        mc = MassCarrier("m", s, energy=[1,2,3,4,5])

        d = Demand(mc, series)

        m = build(d, "demand")

        @test all(mass(getport(m, "input")) .== Stepwise(series, s.mesh))

    end

end
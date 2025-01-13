using Nosy: MassCarrier, EnergyCarrier
using Nosy: mass, energy
using Nosy: Sim, TimeMesh, sim
using Nosy: getport, hasinput, hasoutput
using Nosy: build
using Nosy: DispatchableSource, DispatchableSourceModel

using JuMP: Model

@testset "DispatchableSource" begin

    tsim() = Sim(Model(), mesh=TimeMesh(fill(1//2, 10)))

    let s = tsim()

        mc = MassCarrier("m", s, energy=[1,2,3,4,5])

        d = DispatchableSource(mc)        

        m = build(d, "disp")

        @test !hasinput(m, "input")
        @test hasoutput(m, "output")

        @test !hasport(m, "input")
        @test hasport(m, "output")
        @test !hasport(m, "level")

        @test sim(m) == s

        @test carrier(getport(m, "output")) == mc

    end


end
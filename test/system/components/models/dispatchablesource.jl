using Nosy: MassCarrier
using Nosy: energy
using Nosy: Sim, TimeMesh, sim
using Nosy: _getport, _hasinput, _hasoutput, hasport
using Nosy: carrier
using Nosy: build
using Nosy: DispatchableSource

using JuMP: Model
using Test

@testset "DispatchableSource" begin

    tsim() = Sim(Model(), mesh=TimeMesh(fill(1//2, 10)))

    let s = tsim()

        mc = MassCarrier("m", s, energy=[1,2,3,4,5])

        d = DispatchableSource(mc)        

        m = build(d, "disp")

        @test !_hasinput(m.s, "input", "disp")
        @test _hasoutput(m.s, "output", "disp")

        @test !hasport(m.s, "input", "disp")
        @test hasport(m.s, "output", "disp")
        @test !hasport(m.s, "level", "disp")

        @test sim(m) == s

        @test carrier(_getport(m.s, "output", "disp")) == mc

    end


end

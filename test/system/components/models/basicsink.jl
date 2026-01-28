using Nosy: MassCarrier
using Nosy: Sim, TimeMesh, sim
using Nosy: _getport, _hasinput, _hasoutput
using Nosy: carrier, hasport
using Nosy: build
using Nosy: BasicSink
using Nosy: nvariables, nconstraints

using JuMP: Model
using Test

@testset "BasicSink" begin

    tsim() = Sim(Model(), mesh=TimeMesh(fill(1//2, 10)))

    let s = tsim()

        mc = MassCarrier("m", s, energy=[1,2,3,4,5])

        d = BasicSink(mc)        

        m = build(d, "sink")

        @test _hasinput(m.s, "input", "sink")
        @test !_hasoutput(m.s, "output", "sink")

        @test hasport(m.s, "input", "sink")
        @test !hasport(m.s, "output", "sink")
        @test !hasport(m.s, "level", "sink")

        @test sim(m) == s

        @test carrier(_getport(m.s, "input", "sink")) == mc

        @test nvariables(s) == 10 # input value @ each timestep
        @test nconstraints(s) == 10 # lower bound of input @ each timestep

    end


end

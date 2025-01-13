using Nosy: MassCarrier, EnergyCarrier
using Nosy: mass, energy
using Nosy: Sim, TimeMesh, sim
using Nosy: getport, hasinput, hasoutput
using Nosy: build
using Nosy: BasicSink, BasicSinkModel
using Nosy: nvariables, nconstraints

using JuMP: Model

@testset "BasicSink" begin

    tsim() = Sim(Model(), mesh=TimeMesh(fill(1//2, 10)))

    let s = tsim()

        mc = MassCarrier("m", s, energy=[1,2,3,4,5])

        d = BasicSink(mc)        

        m = build(d, "sink")

        @test hasinput(m, "input")
        @test !hasoutput(m, "output")

        @test hasport(m, "input")
        @test !hasport(m, "output")
        @test !hasport(m, "level")

        @test sim(m) == s

        @test carrier(getport(m, "input")) == mc

        @test nvariables(s) == 10 # input value @ each timestep
        @test nconstraints(s) == 10 # lower bound of input @ each timestep

    end


end
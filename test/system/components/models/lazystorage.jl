using Nosy: MassCarrier, EnergyCarrier
using Nosy: mass, energy
using Nosy: Sim, TimeMesh
using Nosy: portstructure, getport
using Nosy: input, output, level
using Nosy: LazyStorage, LazyStorageModel
using Nosy: FreeJointFlow
using Nosy: Component
using Nosy: nvariables, nconstraints

using JuMP: Model
using ArgCheck: ArgumentError

@testset "LazyStorage" begin

    tsim() = Sim(TimeMesh(fill(1//2, 10)), Model())

    # energy modifier, scalar ratio
    let s = tsim()

        mc = MassCarrier("m", s, energy=[1,2,3,4,5])
        m = LazyStorage(mc, modifier=mass, eff=Dict("jin" =>0.5, "jout" => 1))

        # test on component
        jin = FreeJointFlow("jin", mc, :input)
        jout = FreeJointFlow("jout", mc, :output)
        c = Component("sto", m, [jin, jout])

        @test collect(keys(input(c.s))) == ["jin"]
        @test collect(keys(output(c.s))) == ["jout"]
        @test collect(keys(level(c.s))) == ["level"]

        # testing variables and constraints after component is built
        @test nvariables(s) == 30 # storage level, jin and jout free joint flows @ each timestep
        @test nconstraints(s) == 40 # storage level, jin, jout lower bound @ each timestep + storage constraint @ each timestep

    end


end
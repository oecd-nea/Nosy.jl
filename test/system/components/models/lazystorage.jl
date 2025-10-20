using Nosy: MassCarrier, EnergyCarrier
using Nosy: mass, energy
using Nosy: Sim, TimeMesh
using Nosy: portstructure, getport
using Nosy: _input, _output, _level
using Nosy: LazyStorage, LazyStorageModel
using Nosy: FreeJointFlow
using Nosy: Component
using Nosy: nvariables, nconstraints

using JuMP: Model
using ArgCheck: ArgumentError

@testset "LazyStorage" begin

    tsim() = Sim(Model(), mesh=TimeMesh(fill(1//2, 10)))

    # energy modifier, scalar ratio
    let s = tsim()

        mc = MassCarrier("m", s, energy=[1,2,3,4,5])
        m = LazyStorage(mc, modifier=mass, eff=Dict("jin" =>0.5, "jout" => 1))

        # test on component
        jin = FreeJointFlow("jin", mc, :input)
        jout = FreeJointFlow("jout", mc, :output)
        c = Component("sto", m, [jin, jout])

        @test collect(keys(_input(c.s).d)) == [PortRef("sto", "jin")]
        @test collect(keys(_output(c.s).d)) == [PortRef("sto", "jout")]
        @test collect(keys(_level(c.s).d)) == [PortRef("sto","level")]

        # testing variables and constraints after component is built
        @test nvariables(s) == 30 # storage level, jin and jout free joint flows @ each timestep
        @test nconstraints(s) == 40 # storage level, jin, jout lower bound @ each timestep + storage constraint @ each timestep

    end


end
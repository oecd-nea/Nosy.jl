using Nosy: MassCarrier
using Nosy: mass, energy
using Nosy: Sim, TimeMesh
using Nosy: _input, _output, _level, PortRef
using Nosy: LazyStorage
using Nosy: FreeJointFlow
using Nosy: Component
using Nosy: nvariables, nconstraints

using JuMP: Model
using Test

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

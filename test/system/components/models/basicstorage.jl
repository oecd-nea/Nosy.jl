using Nosy: MassCarrier, EnergyCarrier
using Nosy: mass, energy, co2
using Nosy: Sim, TimeMesh
using Nosy: portstructure, getport
using Nosy: _input, _output, _level
using Nosy: BasicStorage, BasicStorageModel
using Nosy: FixedCapacity
using Nosy: Component
using Nosy: nvariables, nconstraints
using Nosy: _extract

import JuMP
import JuMP: Model, @constraint, set_objective, set_silent, MAX_SENSE, MIN_SENSE
using ArgCheck: ArgumentError
import HiGHS

@testset "BasicStorage" begin

    tsim() = Sim(Model(HiGHS.Optimizer), mesh=TimeMesh(fill(1//2, 10)))

    let s = tsim()

        mc = MassCarrier("m", s, energy=[1,2,3,4,5])

        @test_throws ArgumentError BasicStorage(mc, eff_i=-0.5, eff_o=0.5, modifier=mass) # negative efficiency on input
        @test_throws ArgumentError BasicStorage(mc, eff_i=0.5, eff_o=-0.5, modifier=mass) # negative efficiency on output
        @test_throws ArgumentError BasicStorage(mc, eff_i=0.5, eff_o=0.5, modifier=co2) # modifier not compatible with carrier

        m = BasicStorage(mc, eff_i=0.5, eff_o=1., modifier=mass)

        # test on component
        c = Component("sto", m, [])

        @test collect(keys(_input(c.s))) == ["input"]
        @test collect(keys(_output(c.s))) == ["output"]
        @test collect(keys(_level(c.s))) == ["level"]

        # testing variables and constraints after component is built
        @test nvariables(s) == 30 # storage level, input and output @ each timestep
        @test nconstraints(s) == 40 # storage level, input, output lower bound @ each timestep + storage constraint @ each timestep

    end

    # test storage constraint (input side)
    let s = tsim()

        mc = MassCarrier("m", s, energy=[1,2,3,4,5])

        m = BasicStorage(mc, eff_i=0.5, eff_o=1., modifier=mass)
        icap = FixedCapacity("input", mass, 10.)
        ocap = FixedCapacity("output", mass, 5.)
        lcap = FixedCapacity("level", mass, 40.)

        
        c = Component("sto", m, [icap, ocap, lcap])

        @constraint(sim(c).model, c.model.s.level["level"].series[1] == 0.)
        @constraint(sim(c).model, c.model.s.input["input"].series[1] == 0.)

        set_objective(sim(c).model, MAX_SENSE, c.model.s.level["level"].series[5])
        JuMP.set_silent(sim(c).model)
        JuMP.optimize!(sim(c).model)
        _c = _extract(c)

        @test all(balance(_c, :input, mass, collapse=false)[1:5] .== [0., 10., 10., 10., 10.])
        @test all(balance(_c, :output, mass, collapse=false)[1:5] .== [0., 0., 0., 0., 0.])
        @test all(_c.model.s.level["level"].series[1:5] .== [0., 1.25, 3.75, 6.25, 8.75])

    end

    # test storage constraint (output side)
    let s = tsim()

        mc = MassCarrier("m", s, energy=[1,2,3,4,5])

        m = BasicStorage(mc, eff_i=1., eff_o=2., modifier=mass)
        icap = FixedCapacity("input", mass, 5.)
        ocap = FixedCapacity("output", mass, 10.)
        lcap = FixedCapacity("level", mass, 40.)

        # test on component
        c = Component("sto", m, [icap, ocap, lcap])

        @constraint(sim(c).model, c.model.s.level["level"].series[1] == 40.)
        @constraint(sim(c).model, c.model.s.output["output"].series[1] == 0.)

        set_objective(sim(c).model, MIN_SENSE, c.model.s.level["level"].series[5])
        JuMP.set_silent(sim(c).model)
        JuMP.optimize!(sim(c).model)
        _c = _extract(c)

        @test all(balance(_c, :input, mass, collapse=false)[1:5] .== [0., 0., 0., 0., 0.])
        @test all(balance(_c, :output, mass, collapse=false)[1:5] .== [0., 10., 10., 10., 10.])
        @test all(_c.model.s.level["level"].series[1:5] .== [40., 38.75, 36.25, 33.75, 31.25])

    end
end
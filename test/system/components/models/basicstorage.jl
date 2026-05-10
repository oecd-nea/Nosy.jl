using Nosy: EnergyCarrier, MassCarrier
using Nosy: energy, mass, co2
using Nosy: Sim, TimeMesh, sim
using Nosy: PortRef
using Nosy: _input, _output, _level
using Nosy: BasicStorage
using Nosy: FixedCapacity
using Nosy: Component
using Nosy: nvariables, nconstraints
using Nosy: _extract
using Nosy: _balance

import JuMP
import JuMP: Model, @constraint, set_objective, MAX_SENSE, MIN_SENSE
using ArgCheck: ArgumentError
import HiGHS
using Test

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

        @test collect(keys(_input(c.s).d)) == [PortRef("sto", "input")]
        @test collect(keys(_output(c.s).d)) == [PortRef("sto", "output")]
        @test collect(keys(_level(c.s).d)) == [PortRef("sto", "level")]

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

        @constraint(sim(c).model, c.model.s.level[PortRef("sto", "level")].series[1] == 0.)
        @constraint(sim(c).model, c.model.s.input[PortRef("sto", "input")].series[1] == 0.)

        set_objective(sim(c).model, MAX_SENSE, c.model.s.level[PortRef("sto", "level")].series[5])
        JuMP.set_silent(sim(c).model)
        JuMP.optimize!(sim(c).model)
        _c = _extract(c)

        @test all(_balance(_c, :input, mass, collapse=false)[1:5] .== [0., 10., 10., 10., 10.])
        @test all(_balance(_c, :output, mass, collapse=false)[1:5] .== [0., 0., 0., 0., 0.])
        @test all(_c.model.s.level[PortRef("sto", "level")].series[1:5] .== [0., 1.25, 3.75, 6.25, 8.75])

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

        @constraint(sim(c).model, c.model.s.level[PortRef("sto", "level")].series[1] == 40.)
        @constraint(sim(c).model, c.model.s.output[PortRef("sto", "output")].series[1] == 0.)

        set_objective(sim(c).model, MIN_SENSE, c.model.s.level[PortRef("sto", "level")].series[5])
        JuMP.set_silent(sim(c).model)
        JuMP.optimize!(sim(c).model)
        _c = _extract(c)

        @test all(_balance(_c, :input, mass, collapse=false)[1:5] .== [0., 0., 0., 0., 0.])
        @test all(_balance(_c, :output, mass, collapse=false)[1:5] .== [0., 10., 10., 10., 10.])
        @test all(_c.model.s.level[PortRef("sto", "level")].series[1:5] .== [40., 38.75, 36.25, 33.75, 31.25])

    end

    # test self-discharge, testing with simplified model (input, output are considered as flat during each timestep)
    let s = tsim()

        ec = EnergyCarrier("m", s)

        m = BasicStorage(ec, eff_i=1., eff_o=1., self_discharge=0.1, simplified=true) # 10% self-discharge per hour, using simplified model assuming flat input profile
        icap = FixedCapacity("input", energy, 40.)
        ocap = FixedCapacity("output", energy, 40.)
        lcap = FixedCapacity("level", energy, 40.)

        # test on component
        c = Component("sto", m, [icap, ocap, lcap])

        @constraint(sim(c).model, c.model.s.level[PortRef("sto", "level")].series[1:5] .== [0., 10., 20., 30., 40.]) # constraining level on first steps 

        set_objective(sim(c).model, MIN_SENSE, _balance(c, :input, energy, collapse=true))
        JuMP.set_silent(sim(c).model)
        JuMP.optimize!(sim(c).model)
        _c = _extract(c)

        @test all(_c.model.s.level[PortRef("sto", "level")].series[1:5] .== [0., 10., 20., 30., 40.])
        @test all(_balance(_c, :output, energy, collapse=false)[1:4] .== [0., 0., 0., 0.])       
        l = exp(-0.1 * 0.5) # ratio of energy loss per half-hour
        @test all(isapprox.(_balance(_c, :input, energy, collapse=false)[1:4], [(10 - 0 * l)/0.5, (20 - 10 * l)/0.5, (30 - 20 *l)/0.5, (40 - 30 * l)/0.5]))
        
    end

    # test storage constraint with timesteps longer than one hour
    let s = Sim(Model(HiGHS.Optimizer), mesh=TimeMesh(fill(2//1, 4)))

        ec = EnergyCarrier("m", s)

        m = BasicStorage(ec, eff_i=1., eff_o=1., simplified=true)
        icap = FixedCapacity("input", energy, 40.)
        ocap = FixedCapacity("output", energy, 40.)
        lcap = FixedCapacity("level", energy, 40.)

        c = Component("sto", m, [icap, ocap, lcap])

        @constraint(sim(c).model, c.model.s.level[PortRef("sto", "level")].series.data .== [0., 20., 20., 0.])

        set_objective(sim(c).model, MIN_SENSE, _balance(c, :input, energy, collapse=true))
        JuMP.set_silent(sim(c).model)
        JuMP.optimize!(sim(c).model)
        _c = _extract(c)

        @test all(isapprox.(_balance(_c, :input, energy, collapse=false), [10., 0., 0., 0.]; atol=1e-6))
        @test all(isapprox.(_balance(_c, :output, energy, collapse=false), [0., 0., 10., 0.]; atol=1e-6))

    end

end

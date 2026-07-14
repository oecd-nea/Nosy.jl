using Nosy: energy
using Nosy: Sim, TimeMesh, sim
using Nosy: FixedCapacity
using Nosy: UnitCommitment
using Nosy: FleetUnitCommitmentBehavior, getbehaviors
using Nosy: Ramping
using Nosy: BasicConverter
using Nosy: MassCarrier, EnergyCarrier
using Nosy: Component
using Nosy: _balance, _extract
using JuMP: Model, set_objective, MIN_SENSE, MAX_SENSE, @constraint
import JuMP
using ArgCheck: ArgumentError
import HiGHS
using Test

@testset "Ramping" begin

    tsim() = Sim(Model(HiGHS.Optimizer), mesh=TimeMesh(fill(1//2, 10)))

    function makecomp(vbehavior=[])
        s = tsim()    
        mc = MassCarrier("m", s, energy=[1,2,3,4,5])
        ec = EnergyCarrier("e", s)
        d = BasicConverter(mc, ec)
        c = Component("comp", d, vbehavior)
        return c
    end

    # :nothing is not an allowed Ramping sense
    @test_throws ArgumentError Ramping("output", :nothing, 5.)

    # negative ramp is not allowed
    @test_throws ArgumentError Ramping("output", :up, -2.)


    # ramp up applied through model
    # no unitsize
    let 

        c = makecomp([Ramping("output", :up, 2.), FixedCapacity("output", energy, 8.)])
        
        @constraint(sim(c).model, _balance(c, :output, energy, collapse=false)[1] == 0.)

        set_objective(sim(c).model, MAX_SENSE, _balance(c, :output, energy))
        JuMP.set_silent(sim(c).model)
        JuMP.optimize!(sim(c).model)
        _c = _extract(c)

        @test all(isapprox.(_balance(_c, :output, energy, collapse=false), [0., 1., 2., 3., 4., 5., 6., 7., 8., 8.]))

    end


    # ramp up applied through model with timesteps longer than one hour
    let

        s = Sim(Model(HiGHS.Optimizer), mesh=TimeMesh(fill(2//1, 4)))
        mc = MassCarrier("m", s, energy=[1,2,3,4])
        ec = EnergyCarrier("e", s)
        c = Component("comp", BasicConverter(mc, ec), [
            Ramping("output", :up, 2.),
            FixedCapacity("output", energy, 10.),
        ])

        @constraint(sim(c).model, _balance(c, :output, energy, collapse=false)[1] == 0.)

        set_objective(sim(c).model, MAX_SENSE, _balance(c, :output, energy))
        JuMP.set_silent(sim(c).model)
        JuMP.optimize!(sim(c).model)
        _c = _extract(c)

        @test all(isapprox.(_balance(_c, :output, energy, collapse=false), [0., 4., 8., 10.]; atol=1e-6))

    end


    # ramp down applied through model
    # no unitsize
    let 

        c = makecomp([Ramping("output", :down, 1.), FixedCapacity("output", energy, 2.)])
        
        @constraint(sim(c).model, _balance(c, :output, energy, collapse=false)[3] == 2.)

        set_objective(sim(c).model, MIN_SENSE, _balance(c, :output, energy))
        JuMP.set_silent(sim(c).model)
        JuMP.optimize!(sim(c).model)
        _c = _extract(c)

        @test all(isapprox.(_balance(_c, :output, energy, collapse=false), [0., 0., 2., 1.5, 1., 0.5, 0., 0., 0., 0.]))

    end


    # ramp up applied through model
    # with unitsize
    let 

        c = makecomp([Ramping("output", :up, 1.), FixedCapacity("output", energy, 8., unitsize=2)])
        
        @constraint(sim(c).model, _balance(c, :output, energy, collapse=false)[1] == 0.)

        set_objective(sim(c).model, MAX_SENSE, _balance(c, :output, energy))
        JuMP.set_silent(sim(c).model)
        JuMP.optimize!(sim(c).model)
        _c = _extract(c)

        @test all(isapprox.(_balance(_c, :output, energy, collapse=false), [0., 2., 4., 6., 8., 8., 8., 8., 8., 8.]))

    end


    # ramp down applied through model
    # with unitsize
    let 

        c = makecomp([Ramping("output", :down, 1.), FixedCapacity("output", energy, 8., unitsize=2)])
        
        @constraint(sim(c).model, _balance(c, :output, energy, collapse=false)[1] == 8.)

        set_objective(sim(c).model, MIN_SENSE, _balance(c, :output, energy))
        JuMP.set_silent(sim(c).model)
        JuMP.optimize!(sim(c).model)
        _c = _extract(c)

        @test all(isapprox.(_balance(_c, :output, energy, collapse=false), [8., 6., 4., 2., 0., 0., 0., 0., 0., 0.]))

    end

    # component uc is not compatible
    @test_throws AssertionError makecomp([
        Ramping("output", :down, 1.), 
        FixedCapacity("output", energy, 8., unitsize=2),
        UnitCommitment("input", 0.5),
    ])


    # ramp up applied through fleet unit commitment
    # same modifier as unit commitment
    # no startup time
    let 

        c = makecomp([
            Ramping("output", :up, 0.2), 
            FixedCapacity("output", energy, 5., unitsize=1.),
            UnitCommitment("output", 0.5, shutdownratio=1., integer=true)
        ])
        
        @constraint(sim(c).model, _balance(c, :output, energy, collapse=false)[1] == 0.)
        # @constraint(sim(c).model, _balance(c, :output, energy, collapse=false)[2] == 3.)

        set_objective(sim(c).model, MAX_SENSE, _balance(c, :output, energy))
        JuMP.set_silent(sim(c).model)
        JuMP.optimize!(sim(c).model)
        _c = _extract(c)

        # expected behavior:
        # 1) immediate startup to reach min level (2.5)
        # 2) ramp up until reaching capacity
        @test all(isapprox.(_balance(_c, :output, energy, collapse=false), [0., 2.5, 3., 3.5, 4., 4.5, 5., 5., 5., 5.]))

    end


    # ramp down applied through fleet unit commitment
    # same modifier as unit commitment
    # no shutdown time
    let 

        c = makecomp([
            Ramping("output", :down, 0.2), 
            FixedCapacity("output", energy, 5., unitsize=1.),
            UnitCommitment("output", 0.5, startupratio=1.)
        ])
        
        @constraint(sim(c).model, _balance(c, :output, energy, collapse=false)[1] == 5.)

        set_objective(sim(c).model, MIN_SENSE, _balance(c, :output, energy))
        JuMP.set_silent(sim(c).model)
        JuMP.optimize!(sim(c).model)
        _c = _extract(c)

        # expected behavior:
        # 1) ramp down until uc reaches min level (2.5)
        # 2) immediate shutdown when reaching min level, no ramping constraint applied

        @test all(isapprox.(_balance(_c, :output, energy, collapse=false), [5., 4.5, 4., 3.5, 3., 2.5, 0., 0., 0., 0.]))

    end


    # ramp up applied through fleet unit commitment
    # same modifier as unit commitment
    # startup time
    let 

        c = makecomp([
            Ramping("output", :up, 0.2), 
            FixedCapacity("output", energy, 5., unitsize=1.),
            UnitCommitment("output", 0.5, startup=1, shutdownratio=1., integer=true)
        ])
        
        @constraint(sim(c).model, _balance(c, :output, energy, collapse=false)[1] == 0.)
        # @constraint(sim(c).model, _balance(c, :output, energy, collapse=false)[2] == 3.)

        set_objective(sim(c).model, MAX_SENSE, _balance(c, :output, energy))
        JuMP.set_silent(sim(c).model)
        JuMP.optimize!(sim(c).model)
        _c = _extract(c)

        # expected behavior:
        # 1) immediate startup to reach min level (2.5)
        # 2) ramp up until reaching capacity
        @test all(isapprox.(_balance(_c, :output, energy, collapse=false), [0., 1.25, 2.5, 3., 3.5, 4., 4.5, 5., 5., 5.]))

    end


    # ramp down applied through fleet unit commitment
    # same modifier as unit commitment
    # shutdown time
    let 

        c = makecomp([
            Ramping("output", :down, 0.2), 
            FixedCapacity("output", energy, 5., unitsize=1.),
            UnitCommitment("output", 0.5, shutdown=1, startupratio=1.)
        ])
        
        @constraint(sim(c).model, _balance(c, :output, energy, collapse=false)[1] == 5.)

        set_objective(sim(c).model, MIN_SENSE, _balance(c, :output, energy))
        JuMP.set_silent(sim(c).model)
        JuMP.optimize!(sim(c).model)
        _c = _extract(c)

        # expected behavior:
        # 1) ramp down until uc reaches min level (2.5)
        # 2) immediate shutdown when reaching min level, no ramping constraint applied

        @test all(isapprox.(_balance(_c, :output, energy, collapse=false), [5., 4.5, 4., 3.5, 3., 2.5, 1.25, 0., 0., 0.]))

    end

    # Startup endpoint output above minratio is allowed by the UC ramp constraint.
    let
        c = makecomp([
            Ramping("output", :up, 0.),
            FixedCapacity("output", energy, 1., unitsize=1.),
            UnitCommitment("output", 0.5, startup=1., startupratio=0.8, shutdownratio=1., integer=true),
        ])
        uc = first(getbehaviors(c, FleetUnitCommitmentBehavior))
        flow = _balance(c, :output, energy, collapse=false)

        @constraint(sim(c).model, uc.state[1] == 0.)
        @constraint(sim(c).model, uc.state[2] == 1.)
        set_objective(sim(c).model, MAX_SENSE, flow[2])
        JuMP.set_silent(sim(c).model)
        JuMP.optimize!(sim(c).model)

        @test JuMP.termination_status(sim(c).model) == JuMP.MOI.OPTIMAL
        @test isapprox(JuMP.value(flow[2]), 0.8)
    end

    # Shutdown endpoint output above minratio is allowed by the UC ramp constraint.
    let
        c = makecomp([
            Ramping("output", :down, 0.),
            FixedCapacity("output", energy, 1., unitsize=1.),
            UnitCommitment("output", 0.5, shutdown=1., startupratio=1., shutdownratio=0.8, integer=true),
        ])
        uc = first(getbehaviors(c, FleetUnitCommitmentBehavior))
        flow = _balance(c, :output, energy, collapse=false)

        @constraint(sim(c).model, uc.state[1] == 1.)
        @constraint(sim(c).model, uc.state[2] == 0.)
        set_objective(sim(c).model, MAX_SENSE, flow[1])
        JuMP.set_silent(sim(c).model)
        JuMP.optimize!(sim(c).model)

        @test JuMP.termination_status(sim(c).model) == JuMP.MOI.OPTIMAL
        @test isapprox(JuMP.value(flow[1]), 0.8)
    end
end

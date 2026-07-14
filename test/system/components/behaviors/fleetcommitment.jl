using Nosy: mass, energy
using Nosy: Sim, TimeMesh, nvariables, nconstraints, sim, nsteps, nhours
using Nosy: VariableCapacity, FixedCapacity, FixedComposedCapacity
using Nosy: UnitCommitment, FleetUnitCommitmentBehavior, _up
using Nosy: getbehaviors
using Nosy: BasicConverter
using Nosy: MassCarrier, EnergyCarrier
using Nosy: Component
using Nosy: _balance, _extract
using JuMP: Model, set_objective, MIN_SENSE, MAX_SENSE, @constraint
import JuMP
using ArgCheck: ArgumentError
import HiGHS
using DataFrames
using Primes: nextprime
using Test

"""
Testing unit commitment constraints is difficult.
Some notes and observations:
  * all tests are based on minimizing or maximizing the sum of the input balance of a converter. This should guarantee a given order (as in: no shift) of the commitment vector as the energy to mass ratio of the mass carrier is not constant
  * the startup and shutdown duration are tricky: when smaller than the duration of a step, they actually take the duration of the step.
  * the function _uctable is used to analyze the content of the unit commitment behavior.
  * the tests on the number of constraints and variables don't define the "correct" number of constraints and variables, but they are a check for when modifying the UC constraints.
"""

@testset "Fleet unit commitment" begin

    tsim() = Sim(Model(HiGHS.Optimizer), mesh=TimeMesh(fill(1//2, 10)))

    function weighted_balance_sum(c::Component, dir, carrier)
        b = _balance(c, dir, carrier, collapse=false)
        return sum(b[i] * sqrt(nextprime(1, interval=i))  for i in eachindex(b)) # Q-linearly independent weights to remove equivalent solutions, using square root of primes
    end

    # circular time (default)
    function makecomp(vbehavior=[])
        s = tsim()    
        mc = MassCarrier("m", s, energy=[1,2,3,4,5])
        ec = EnergyCarrier("e", s)
        d = BasicConverter(mc, ec)
        c = Component("comp", d, vbehavior)
        return c
    end

    # non-circular time
    function makecomp_opentime(vbehavior=[]; weights=fill(1//1, 10))
        s = Sim(Model(HiGHS.Optimizer), mesh=TimeMesh(weights; circular=false))
        mc = MassCarrier("m", s, energy=ones(nsteps(s)))
        ec = EnergyCarrier("e", s)
        d = BasicConverter(mc, ec)
        c = Component("comp", d, vbehavior)
        return c
    end

    # convenience tool to analyze content of unit commitment
    function _uctable(c::Component)
        uc = first(getbehaviors(c, FleetUnitCommitmentBehavior))
        df = DataFrame()
        df[!, "t"] = 1:nsteps(sim(c))
        df[!,"uc"] = uc.state.data
        df[!,"st"] = uc.startup.data
        df[!,"sd1"] = uc.shutdownselector[1].data
        df[!,"sd2"] = length(uc.shutdownselector) > 1 ? uc.shutdownselector[2].data : zeros(nsteps(sim(c)))
        df[!,"v"] = uc.variable.data
        df[!, "up"] = _up(uc)
        df[!,"b"] = _balance(c, :output, energy, collapse=false)
        return df
    end


    @test_throws ArgumentError UnitCommitment("input", -0.5) # negative minratio not allowed
    @test_throws ArgumentError UnitCommitment("input", 1.5) # minratio superior to 1 not allowed
    @test_throws ArgumentError UnitCommitment("input", 0.5, startup=-1) # negative startup not allowed
    @test_throws ArgumentError UnitCommitment("input", 0.5, shutdown=-1) # negative shutdown not allowed
    @test_throws ArgumentError UnitCommitment("input", 0.5, uptime=-1) # negative uptime not allowed
    @test_throws ArgumentError UnitCommitment("input", 0.5, downtime=-1) # negative downtime not allowed
    @test_throws ArgumentError UnitCommitment("input", 0.5, startupratio=-0.5) # startup ratio cannot be negative
    @test_throws ArgumentError UnitCommitment("input", 0.5, startupratio=1.25) # startup ratio cannot be superior to 1
    @test_throws ArgumentError UnitCommitment("input", 0.5, startupratio=0.25) # startup ratio cannot be lower than minratio
    @test_throws ArgumentError UnitCommitment("input", 0.5, shutdownratio=-0.5) # shutdown ratio cannot be lower than minratio
    @test_throws ArgumentError UnitCommitment("input", 0.5, shutdownratio=1.25) # shutdown ratio cannot be superior to 1
    @test_throws ArgumentError UnitCommitment("input", 0.5, shutdownratio=0.25) # shutdown ratio cannot be lower than minratio
    @test_throws ArgumentError UnitCommitment("input", 0.5, downtime=1.0, shutdownmask=[fill(true, 10), fill(true, 10)]) # downtime length 1 needs shutdownmask length 1
    @test_throws ArgumentError UnitCommitment("input", 0.5, downtime=[1.0, 2.0], shutdownmask=[fill(true, 10)]) # downtime length 2 needs shutdownmask length 2

    let
        cap = FixedCapacity("input", mass, 10., unitsize=5.)
        uc = UnitCommitment("input", 0.5, startup=0, shutdown=0, uptime=0, downtime=0, startupmask=fill(true, 9))
        @test_throws ArgumentError makecomp([cap, uc]) # can't catch this error earlier because time mesh unknown at UC level
    end

    let
        cap = FixedCapacity("input", mass, 10., unitsize=5.)
        uc = UnitCommitment("input", 0.5, startup=0, shutdown=0, uptime=0, downtime=0, shutdownmask=[fill(true, 9)])
        @test_throws ArgumentError makecomp([cap, uc]) # can't catch this error earlier because time mesh unknown at UC level
    end


    let   
        uc = UnitCommitment("input", 0.5, startup=0, shutdown=0, uptime=0, downtime=0, integer=false)
             
        # unit commitment requires capacity
        @test_throws AssertionError makecomp([uc])

    end

    let   
        cap = FixedCapacity("input", mass, 11., unitsize=5.)
        uc = UnitCommitment("input", 0.5, startup=0, shutdown=0, uptime=0, downtime=0, integer=true)
        
        # unit commitment with integer variables not compatible with fixed capacity with non-integer number of units
        @test_throws ArgumentError makecomp([cap, uc])
        
    end

    let   
        cap = FixedCapacity("input", mass, 10., unitsize=5.)
        uc = UnitCommitment("input", 0.5, startup=0, shutdown=0, uptime=0, downtime=0, integer=false)

        m = makecomp([cap, uc])
        
        # check correct dispatch into FleetUnitCommitmentBehavior
        @test m.behaviors[2] isa FleetUnitCommitmentBehavior

    end

    # masked-out startup and shutdown events should not create redundant UC rows
    let
        cap = FixedCapacity("input", mass, 10., unitsize=5.)
        mask = fill(false, 10)
        uc = UnitCommitment("input", 1., startup=0, shutdown=0, uptime=0, downtime=0, integer=true,
            startupmask=mask, shutdownmask=[mask]
        )

        m = makecomp([cap, uc])

        @test nvariables(sim(m)) == 11
        @test nconstraints(sim(m)) == 33
    end

    # Commitment must be coupled to the capacity actually built even when all
    # shutdown variables are masked out. Without the explicit units constraint,
    # the minimum-downtime rows disappear and state could reach the build upper
    # bound while installed capacity remained zero.
    let
        cap = VariableCapacity("input", mass, ub=10., unitsize=5., integer=true)
        mask = fill(false, 10)
        uc = UnitCommitment("input", 0., integer=true, shutdownmask=[mask])

        m = makecomp([cap, uc])
        cap_behavior = first(getbehaviors(m, Nosy.VariableCapacityBehavior))
        uc_behavior = first(getbehaviors(m, FleetUnitCommitmentBehavior))

        @constraint(sim(m).model, cap_behavior.val == 0.)
        set_objective(sim(m).model, MAX_SENSE, sum(uc_behavior.state.data))
        JuMP.set_silent(sim(m).model)
        JuMP.optimize!(sim(m).model)

        @test JuMP.termination_status(sim(m).model) == JuMP.MOI.OPTIMAL
        @test all(iszero.(JuMP.value.(uc_behavior.state.data)))
    end

    # Unit count must come from the capacity attached to the committed port,
    # not from a component-wide unique-capacity lookup.
    let
        input_cap = FixedCapacity("input", mass, 10., unitsize=5.)
        output_cap = VariableCapacity("output", energy, ub=20.)
        uc = UnitCommitment("input", 0.5, integer=true)

        m = makecomp([input_cap, output_cap, uc])
        @test length(getbehaviors(m, FleetUnitCommitmentBehavior)) == 1
    end

    #=
        t	uc	st	sd	v	up	b
        1	0.0	0.0	0.0	0.0	0.0	0.0
        2	2.0	2.0	2.0	0.0	2.0	5.0
        3	0.0	0.0	0.0	0.0	0.0	0.0
        4	2.0	2.0	0.0	0.0	2.0	5.0
        5	2.0	0.0	0.0	5.0	2.0	10.0
        6	2.0	0.0	0.0	5.0	2.0	10.0
        7	2.0	0.0	0.0	5.0	2.0	10.0
        8	2.0	0.0	0.0	5.0	2.0	10.0
        9	2.0	0.0	0.0	5.0	2.0	10.0
        10	2.0	0.0	2.0	0.0	2.0	5.0
    =#
    let   
        cap = FixedCapacity("input", mass, 10., unitsize=5.)
        uc = UnitCommitment("input", 0.5, startup=0, shutdown=0, uptime=0, downtime=0, integer=false)
        
        m = makecomp([cap, uc])
        
        # variables
        # 10 for converter
        # 0 for capacity (fixed)
        # 30 for UC (startup, shutdown, state); variable dispatch reuses the converter flow
        @test nvariables(sim(m)) == 40
        
        # constraints
        # 10 for converter lower bound
        # 10 for capacity
        # 30 for uc variable lower bounds (startup, shutdown, state)
        # 30 for uc variable upper bounds (startup, shutdown, state)
        # 10 for uc switch constraint
        # 10 for uc variable dispatch lower bound
        # 20 for uc startup and shutdown endpoint flow constraints
        # 0 for uc units constraint (fixed capacity is enforced by the state variable upper bound)
        # 0 for uc min uptime constraint (uptime=0)
        # 10 for uc min downtime constraint (downtime=0 but startup and shutdown are actually included and take at least one step each - even when duration is 0)
        # 10 for shutdown <= uc constraint
        @test nconstraints(sim(m)) == 140
        
        # test: maximum capacity can be reached, even with constraint of 0 flow at some point
        # no startup / shutdown constraints
        @constraint(sim(m).model, _balance(m, :output, energy, collapse=false)[1] == 0.)
        @constraint(sim(m).model, _balance(m, :output, energy, collapse=false)[3] == 0.)
        # Startup and shutdown endpoints remain capped at minratio; maximum
        # output is reached on the regular committed steps 5:9.
        set_objective(sim(m).model, MAX_SENSE, weighted_balance_sum(m, :input, energy))
        JuMP.set_silent(sim(m).model)
        JuMP.optimize!(sim(m).model)
        _m = _extract(m)
        # _uctable(_m)
        @test all(_balance(_m, :output, energy, collapse=false) .== [0., 5., 0., 5., 10., 10., 10., 10., 10., 5.])
        @test all(_up(_m.behaviors[2]) .== [0, 2, 0, 2, 2, 2, 2, 2, 2, 2])
    end

    #=
    t	uc	st	sd	v	up	b
    1	0.0	0.0	0.0	0.0	0.0	0.0
    2	0.0	0.0	0.0	0.0	0.0	0.0
    3	0.0	0.0	0.0	0.0	0.0	0.0
    4	0.0	0.0	0.0	0.0	0.0	0.0
    5	0.0	0.0	0.0	0.0	0.0	0.0
    6	0.0	0.0	0.0	0.0	0.0	0.0
    7	0.0	0.0	0.0	0.0	0.0	0.0
    8	0.0	0.0	0.0	0.0	0.0	0.0
    9	0.0	0.0	0.0	0.0	0.0	0.0
    10	0.0	0.0	0.0	0.0	0.0	0.0
    =#
    let   
        cap = FixedCapacity("input", mass, 10., unitsize=5.)
        uc = UnitCommitment("input", 0.5, startup=3, shutdown=2, uptime=0, downtime=0, integer=false)
        
        m = makecomp([cap, uc])
        
        # test: startup and shutdown
        @constraint(sim(m).model, _balance(m, :output, energy, collapse=false)[1] == 0.)
        @constraint(sim(m).model, _balance(m, :output, energy, collapse=false)[5] == 0.)
        # maximum can't be reached: no time because of startup / shutdown time
        # output should always stay at 0
        set_objective(sim(m).model, MAX_SENSE, weighted_balance_sum(m, :input, energy))
        JuMP.set_silent(sim(m).model)
        JuMP.optimize!(sim(m).model)
        _m = _extract(m)
        # _uctable(_m)
        @test all(_balance(_m, :output, energy, collapse=false) .== 0.)
        @test all(_up(_m.behaviors[2]) .== 0.)
    end

    #=
    t	uc	st	sd	v	up	b
    1	1.0	0.0	0.0	0.0	1.0	5.0
    2	1.0	0.0	0.0	0.0	1.0	5.0
    3	1.0	0.0	1.0	0.0	1.0	5.0
    4	0.0	0.0	0.0	0.0	1.0	2.5
    5	0.0	0.0	0.0	0.0	0.0	0.0
    6	0.0	0.0	0.0	0.0	1.0	2.5
    7	1.0	1.0	0.0	0.0	1.0	5.0
    8	1.0	0.0	0.0	0.0	1.0	5.0
    9	1.0	0.0	0.0	0.0	1.0	5.0
    10	1.0	0.0	0.0	0.0	1.0	5.0
    =#
    let   
        cap = FixedCapacity("input", mass, 5., unitsize=5.)
        uc = UnitCommitment("input", 1., startup=1, shutdown=1, uptime=0, downtime=0, integer=false)
        
        m = makecomp([cap, uc])
        
        # test: startup and shutdown
        @constraint(sim(m).model, _balance(m, :output, energy, collapse=false)[5] == 0.)
        @constraint(sim(m).model, m.behaviors[2].shutdown[3] == 1.)
        # @constraint(sim(m).model, m.behaviors[2].startup[7] == 1.)
        
        set_objective(sim(m).model, MAX_SENSE, weighted_balance_sum(m, :input, energy))
        JuMP.set_silent(sim(m).model)
        JuMP.optimize!(sim(m).model)
        _m = _extract(m)
        # _uctable(_m)
        @test all(_balance(_m, :output, energy, collapse=false) .== [5., 5., 5., 2.5, 0., 2.5, 5., 5., 5., 5.])
        @test all(_up(_m.behaviors[2]) .== [1, 1, 1, 1, 0, 1, 1, 1, 1, 1])
    end

    #=
    t	uc	st	sd	v	up	b
    1	0.0	0.0	0.0	0.0	0.0	0.0
    2	0.0	0.0	0.0	0.0	0.0	0.0
    3	0.0	0.0	0.0	0.0	0.0	0.0
    4	0.0	0.0	0.0	0.0	2.0	2.5
    5	2.0	2.0	0.0	0.0	2.0	5.0
    6	2.0	0.0	0.0	0.0	2.0	5.0
    7	2.0	0.0	2.0	0.0	2.0	5.0
    8	0.0	0.0	0.0	0.0	2.0	2.5
    9	0.0	0.0	0.0	0.0	0.0	0.0
    10	0.0	0.0	0.0	0.0	0.0	0.0
    =#
    let   
        cap = FixedCapacity("input", mass, 10., unitsize=5.)
        uc = UnitCommitment("input", 0.5, startup=1, shutdown=1, uptime=1, downtime=0, integer=true)
        
        m = makecomp([cap, uc])
        
        # test: min uptime
        @constraint(sim(m).model, _balance(m, :output, energy, collapse=false)[3] == 0.)
        @constraint(sim(m).model, _balance(m, :output, energy, collapse=false)[5] == 5.)

        set_objective(sim(m).model, MIN_SENSE, weighted_balance_sum(m, :input, energy))
        JuMP.set_silent(sim(m).model)
        JuMP.optimize!(sim(m).model)
        _m = _extract(m)
        # _uctable(_m)
        @test all(_balance(_m, :output, energy, collapse=false) .== [0., 0., 0., 2.5, 5., 5., 5., 2.5, 0., 0.])
        @test all(_up(_m.behaviors[2]) .== [0., 0., 0., 2., 2., 2., 2., 2., 0., 0.])
    end

    #=
    t	uc	st	sd	v	up	b
    1	2.0	0.0	0.0	5.0	2.0	10.0
    2	2.0	0.0	0.0	5.0	2.0	10.0
    3	2.0	0.0	2.0	0.0	2.0	5.0
    4	0.0	0.0	0.0	0.0	2.0	2.5
    5	0.0	0.0	0.0	0.0	0.0	0.0
    6	0.0	0.0	0.0	0.0	0.0	0.0
    7	0.0	0.0	0.0	0.0	0.0	0.0
    8	0.0	0.0	0.0	0.0	2.0	2.5
    9	2.0	2.0	0.0	0.0	2.0	5.0
    10	2.0	0.0	0.0	5.0	2.0	10.0
    =#
    let   
        cap = FixedCapacity("input", mass, 10., unitsize=5.)
        uc = UnitCommitment("input", 0.5, startup=1, shutdown=1, uptime=0, downtime=1, integer=true)
        
        m = makecomp([cap, uc])
        
        # test: startup and shutdown + downtime
        @constraint(sim(m).model, _balance(m, :output, energy, collapse=false)[3] == 5.)
        @constraint(sim(m).model, _balance(m, :output, energy, collapse=false)[5] == 0.)

        set_objective(sim(m).model, MAX_SENSE, weighted_balance_sum(m, :input, energy))
        JuMP.set_silent(sim(m).model)
        JuMP.optimize!(sim(m).model)
        _m = _extract(m)
        # _uctable(_m)
        @test all(_balance(_m, :output, energy, collapse=false) .== [10., 10., 5., 2.5, 0., 0., 0., 2.5, 5., 10.])
        @test all(_up(_m.behaviors[2]) .== [2., 2., 2., 2., 0., 0., 0., 2., 2., 2.])
    end

    #=
    t	uc	st	sd	v	up	b
    1	0.0	0.0	0.0	0.0	2.0	5.0
    2	0.0	0.0	0.0	0.0	2.0	7.5
    3	2.0	2.0	2.0	0.0	2.0	10.0
    4	0.0	0.0	0.0	0.0	2.0	5.0
    5	0.0	0.0	0.0	0.0	0.0	0.0
    6	0.0	0.0	0.0	0.0	0.0	0.0
    7	0.0	0.0	0.0	0.0	0.0	0.0
    8	0.0	0.0	0.0	0.0	0.0	0.0
    9	0.0	0.0	0.0	0.0	0.0	0.0
    10	0.0	0.0	0.0	0.0	2.0	2.5
    =#
    let   
        cap = FixedCapacity("input", mass, 10., unitsize=5.)
        uc = UnitCommitment("input", 1., startup=2, shutdown=1, uptime=0, downtime=2, integer=true)
        
        m = makecomp([cap, uc])
        
        # test: startup and shutdown + downtime
        @constraint(sim(m).model, _balance(m, :output, energy, collapse=false)[3] == 10.)
        @constraint(sim(m).model, _balance(m, :output, energy, collapse=false)[5] == 0.)

        set_objective(sim(m).model, MAX_SENSE, weighted_balance_sum(m, :input, energy))
        JuMP.set_silent(sim(m).model)
        JuMP.optimize!(sim(m).model)
        _m = _extract(m)
        # _uctable(_m)
        @test all(_balance(_m, :output, energy, collapse=false) .== [5., 7.5, 10., 5., 0., 0., 0., 0., 0., 2.5])
        @test all(_up(_m.behaviors[2]) .== [2., 2., 2., 2., 0., 0., 0., 0., 0., 2.])
    end
    
    #=
    t	uc	st	sd	v	up	b
    1	0.0	0.0	0.0	0.0	2.0	5.0
    2	0.0	0.0	0.0	0.0	2.0	7.5
    3	2.0	2.0	2.0	0.0	2.0	10.0
    4	0.0	0.0	0.0	0.0	2.0	5.0
    5	0.0	0.0	0.0	0.0	0.0	0.0
    6	0.0	0.0	0.0	0.0	0.0	0.0
    7	0.0	0.0	0.0	0.0	0.0	0.0
    8	0.0	0.0	0.0	0.0	0.0	0.0
    9	0.0	0.0	0.0	0.0	0.0	0.0
    10	0.0	0.0	0.0	0.0	2.0	2.5
    =#
    let   
        cap = VariableCapacity("input", mass, ub=10., unitsize=5.)
        uc = UnitCommitment("input", 1., startup=2, shutdown=1, uptime=0, downtime=2, integer=true)
        
        m = makecomp([cap, uc])
        
        # test: startup and shutdown + downtime
        @constraint(sim(m).model, _balance(m, :output, energy, collapse=false)[3] == 10.)
        @constraint(sim(m).model, _balance(m, :output, energy, collapse=false)[5] == 0.)

        set_objective(sim(m).model, MAX_SENSE, weighted_balance_sum(m, :input, energy))
        JuMP.set_silent(sim(m).model)
        JuMP.optimize!(sim(m).model)
        _m = _extract(m)
        # _uctable(_m)
        @test all(_balance(_m, :output, energy, collapse=false) .== [5., 7.5, 10., 5., 0., 0., 0., 0., 0., 2.5])
        @test all(_up(_m.behaviors[2]) .== [2., 2., 2., 2., 0., 0., 0., 0., 0., 2.])
    end

    #=
    t	uc	st	sd	v	up	b
    1	0.0	0.0	0.0	0.0	2.0	2.5
    2	0.0	0.0	0.0	0.0	2.0	3.75
    3	2.0	2.0	2.0	0.0	2.0	5.0
    4	0.0	0.0	0.0	0.0	2.0	2.5
    5	0.0	0.0	0.0	0.0	0.0	0.0
    6	0.0	0.0	0.0	0.0	0.0	0.0
    7	0.0	0.0	0.0	0.0	0.0	0.0
    8	0.0	0.0	0.0	0.0	0.0	0.0
    9	0.0	0.0	0.0	0.0	0.0	0.0
    10	0.0	0.0	0.0	0.0	2.0	1.25
    =#
    let   
        cap = VariableCapacity("input", mass, ub=10., unitsize=5.)
        uc = UnitCommitment("input", 0.5, startup=2, shutdown=1, uptime=0, downtime=2, integer=true)
        
        m = makecomp([cap, uc])
        
        # variables
        # 10 for converter
        # 1 for capacity
        # 30 for UC (startup, shutdown, state); variable dispatch reuses the converter flow
        @test nvariables(sim(m)) == 41
        
        # constraints
        # 10 for converter lower bound
        # 2 for capacity lb and ub
        # 10 for capacity
        # 30 for uc variable lower bounds (startup, shutdown, state)
        # 30 for uc variable upper bounds (startup, shutdown, state)
        # 30 for uc attributes integer constraint (startup, shutdown, state)
        # 10 for uc switch constraint
        # 10 for uc variable dispatch lower bound
        # 20 for uc startup and shutdown endpoint flow constraints
        # 10 for uc units constraint (state cannot exceed built capacity)
        # 0 for uc min uptime constraint (uptime=0)
        # 10 for uc min downtime constraint
        # 10 for shutdown <= uc constraint
        @test nconstraints(sim(m)) == 182

        # test: startup and shutdown + downtime
        @constraint(sim(m).model, _balance(m, :output, energy, collapse=false)[3] == 5.)
        @constraint(sim(m).model, _balance(m, :output, energy, collapse=false)[5] == 0.)

        set_objective(sim(m).model, MAX_SENSE, weighted_balance_sum(m, :input, energy))
        JuMP.set_silent(sim(m).model)
        JuMP.optimize!(sim(m).model)
        _m = _extract(m)
        # _uctable(_m)
        @test all(_balance(_m, :output, energy, collapse=false) .== [2.5, 3.75, 5., 2.5, 0., 0., 0., 0., 0., 1.25])
        @test all(_up(_m.behaviors[2]) .== [2., 2., 2., 2., 0., 0., 0., 0., 0., 2.])
    end

    #=
    t	uc	st	sd	v	up	b
    1	1.0	0.0	1.0	0.0	1.0	5.0
    2	0.0	0.0	0.0	0.0	1.0	2.5
    3	0.0	0.0	0.0	0.0	0.0	0.0
    4	0.0	0.0	0.0	0.0	0.0	0.0
    5	0.0	0.0	0.0	0.0	0.0	0.0
    6	0.0	0.0	0.0	0.0	1.0	2.5
    7	1.0	1.0	0.0	0.0	1.0	5.0
    8	1.0	0.0	0.0	0.0	1.0	5.0
    9	1.0	0.0	0.0	0.0	1.0	5.0
    10	1.0	0.0	0.0	0.0	1.0	5.0
    =#
    let   
        cap = VariableCapacity("input", mass, ub=5., unitsize=5.)
        uc = UnitCommitment("input", 1., startup=1, shutdown=1, uptime=1, downtime=1, integer=true)
        
        m = makecomp([cap, uc])
        
        # test: startup and shutdown + downtime
        @constraint(sim(m).model, _balance(m, :output, energy, collapse=false)[5] == 0.)

        set_objective(sim(m).model, MAX_SENSE, weighted_balance_sum(m, :input, energy))
        JuMP.set_silent(sim(m).model)
        JuMP.optimize!(sim(m).model)
        _m = _extract(m)
        # _uctable(_m)
        @test all(_balance(_m, :output, energy, collapse=false) .== [5., 2.5, 0., 0., 0., 2.5, 5., 5., 5., 5.])
        @test all(_up(_m.behaviors[2]) .== [1., 1., 0., 0., 0., 1., 1., 1., 1., 1.])
    end

    #=
    t	uc	st	sd	v	up	b
    1	2.0	2.0	0.0	0.0	2.0	10.0
    2	2.0	0.0	0.0	0.0	2.0	10.0
    3	2.0	0.0	2.0	0.0	2.0	10.0
    4	0.0	0.0	0.0	0.0	2.0	5.0
    5	0.0	0.0	0.0	0.0	0.0	0.0
    6	0.0	0.0	0.0	0.0	0.0	0.0
    7	0.0	0.0	0.0	0.0	0.0	0.0
    8	0.0	0.0	0.0	0.0	0.0	0.0
    9	0.0	0.0	0.0	0.0	0.0	0.0
    10	0.0	0.0	0.0	0.0	2.0	5.0
    =#
    let   
        cap = VariableCapacity("input", mass, ub=10., unitsize=5.)
        uc = UnitCommitment("input", 1., startup=1, shutdown=1, uptime=1, downtime=1, integer=true)
        
        m = makecomp([cap, uc])
        
        # test: startup and shutdown + downtime
        @constraint(sim(m).model, _balance(m, :output, energy, collapse=false)[3] == 10.)
        @constraint(sim(m).model, _balance(m, :output, energy, collapse=false)[5] == 0.)

        set_objective(sim(m).model, MIN_SENSE, weighted_balance_sum(m, :input, energy))
        JuMP.set_silent(sim(m).model)
        JuMP.optimize!(sim(m).model)
        _m = _extract(m)
        # _uctable(_m)
        @test all(_balance(_m, :output, energy, collapse=false) .== [10., 10., 10., 5., 0., 0., 0., 0., 0., 5.])
        @test all(_up(_m.behaviors[2]) .== [2., 2., 2., 2., 0., 0., 0., 0., 0., 2.])
    end

    #=
    t	uc	st	sd	v	up	b
    1	2.0	2.0	2.0	0.0	2.0	10.0
    2	0.0	0.0	0.0	0.0	2.0	7.5
    3	0.0	0.0	0.0	0.0	2.0	5.0
    4	0.0	0.0	0.0	0.0	2.0	2.5
    5	0.0	0.0	0.0	0.0	0.0	0.0
    6	0.0	0.0	0.0	0.0	0.0	0.0
    7	0.0	0.0	0.0	0.0	0.0	0.0
    8	0.0	0.0	0.0	0.0	0.0	0.0
    9	0.0	0.0	0.0	0.0	0.0	0.0
    10	0.0	0.0	0.0	0.0	0.0	0.0
    =#
    let   
        cap = VariableCapacity("input", mass, ub=10., unitsize=5.)
        uc = UnitCommitment("input", 1., startup=0, shutdown=2., uptime=0, downtime=0, integer=true)
        
        m = makecomp([cap, uc])
        
        # test: startup and shutdown + downtime
        @constraint(sim(m).model, _balance(m, :output, energy, collapse=false)[1] == 10.)

        set_objective(sim(m).model, MIN_SENSE, weighted_balance_sum(m, :input, energy))
        JuMP.set_silent(sim(m).model)
        JuMP.optimize!(sim(m).model)
        _m = _extract(m)
        # _uctable(_m)
        @test all(isapprox.(_balance(_m, :output, energy, collapse=false), [10., 7.5, 5., 2.5, 0., 0., 0., 0., 0., 0.]))
        @test all(_up(_m.behaviors[2]) .== [2., 2., 2., 2., 0., 0., 0., 0., 0., 0.])
    end

    #=
    t	uc	st	sd	v	up	b
    1	2.0	2.0	0.0	0.0	2.0	10.0
    2	2.0	0.0	2.0	0.0	2.0	10.0
    3	0.0	0.0	0.0	0.0	2.0	5.0
    4	0.0	0.0	0.0	0.0	0.0	0.0
    5	0.0	0.0	0.0	0.0	0.0	0.0
    6	0.0	0.0	0.0	0.0	0.0	0.0
    7	0.0	0.0	0.0	0.0	0.0	0.0
    8	0.0	0.0	0.0	0.0	2.0	2.5
    9	0.0	0.0	0.0	0.0	2.0	5.000000000000001 # numeric error here
    10	0.0	0.0	0.0	0.0	2.0	7.5
    =#
    let   
        cap = VariableCapacity("input", mass, ub=10., unitsize=5.)
        uc = UnitCommitment("input", 1., startup=2, shutdown=1, uptime=0.5, downtime=1, integer=true)
        
        m = makecomp([cap, uc])
        
        # test: startup and shutdown + downtime
        @constraint(sim(m).model, _balance(m, :output, energy, collapse=false)[1] == 10.)

        set_objective(sim(m).model, MIN_SENSE, weighted_balance_sum(m, :input, energy))
        JuMP.set_silent(sim(m).model)
        JuMP.optimize!(sim(m).model)
        _m = _extract(m)
        # _uctable(_m)
        @test all(isapprox.(_balance(_m, :output, energy, collapse=false), [10., 10., 5., 0., 0., 0., 0., 2.5, 5., 7.5]))
        @test all(isapprox.(_up(_m.behaviors[2]), [2., 2., 2., 0., 0., 0., 0., 2., 2., 2.]))
    end

    #=
    t	uc	st	sd	v	up	b
    1	1.0	0.0	1.0	0.0	1.0	5.0
    2	0.0	0.0	0.0	0.0	0.0	0.0
    3	0.0	0.0	0.0	0.0	0.0	0.0
    4	0.0	0.0	0.0	0.0	0.0	0.0
    5	0.0	0.0	0.0	0.0	0.0	0.0
    6	0.0	0.0	0.0	0.0	1.0	1.25
    7	0.0	0.0	0.0	0.0	1.0	2.5
    8	0.0	0.0	0.0	0.0	1.0	3.75
    9	1.0	1.0	0.0	0.0	1.0	5.0
    10	1.0	0.0	0.0	0.0	1.0	5.0
    =#
    let   
        cap = VariableCapacity("input", mass, ub=5., unitsize=5.)
        uc = UnitCommitment("input", 1., startup=2., shutdown=0., uptime=0., downtime=1.5, integer=true)
        
        m = makecomp([cap, uc])
        
        # test: startup and shutdown + downtime
        @constraint(sim(m).model, _balance(m, :output, energy, collapse=false)[5] == 0.)

        set_objective(sim(m).model, MAX_SENSE, weighted_balance_sum(m, :input, energy))
        JuMP.set_silent(sim(m).model)
        JuMP.optimize!(sim(m).model)
        _m = _extract(m)
        # _uctable(_m)
        @test all(isapprox.(_balance(_m, :output, energy, collapse=false), [5., 0., 0., 0., 0., 1.25, 2.5, 3.75, 5., 5.]))
        @test all(_up(_m.behaviors[2]) .== [1., 0., 0., 0., 0., 1., 1., 1., 1., 1.])
    end

    #=
    t	uc	st	sd	v	up	b
    1	0.0	0.0	0.0	0.0	0.0	0.0
    2	0.0	0.0	0.0	0.0	0.0	0.0
    3	0.0	0.0	0.0	0.0	0.0	0.0
    4	0.0	0.0	0.0	0.0	0.0	0.0
    5	1.0	1.0	0.0	0.0	1.0	5.0
    6	1.0	0.0	0.0	0.0	1.0	5.0
    7	1.0	0.0	0.0	0.0	1.0	5.0
    8	1.0	0.0	0.0	0.0	1.0	5.0
    9	1.0	0.0	1.0	0.0	1.0	5.0
    10	0.0	0.0	0.0	0.0	0.0	0.0
    =#
    let   
        cap = VariableCapacity("input", mass, ub=5., unitsize=5.)
        # uc = UnitCommitment("input", 1., startup=0., shutdown=1.5, uptime=0.5, downtime=0.5, integer=true)
        uc = UnitCommitment("input", 1., startup=0., shutdown=0., uptime=0., downtime=2., integer=true)
        
        m = makecomp([cap, uc])
        
        # test: startup and shutdown + downtime
        @constraint(sim(m).model, _balance(m, :output, energy, collapse=false)[1] == 0.)

        set_objective(sim(m).model, MAX_SENSE, weighted_balance_sum(m, :input, energy))
        JuMP.set_silent(sim(m).model)
        JuMP.optimize!(sim(m).model)
        _m = _extract(m)
        # _uctable(_m)
        @test all(isapprox.(_balance(_m, :output, energy, collapse=false), [0., 0., 0., 0., 5., 5., 5., 5., 5., 0.]))
        @test all(_up(_m.behaviors[2]) .== [0., 0., 0., 0., 1., 1., 1., 1., 1., 0.])
    end
   
    #=
    t	uc	st	sd	v	up	b
    1	0.0	0.0	0.0	0.0	0.0	0.0
    2	0.0	0.0	0.0	0.0	0.0	0.0
    3	0.0	0.0	0.0	0.0	1.0	0.625
    4	0.0	0.0	0.0	0.0	1.0	1.25
    5	0.0	0.0	0.0	0.0	1.0	1.875
    6	1.0	1.0	0.0	0.0	1.0	2.5
    7	1.0	0.0	0.0	2.5	1.0	5.0
    8	1.0	0.0	0.0	2.5	1.0	5.0
    9	1.0	0.0	1.0	2.5	1.0	5.0
    10	0.0	0.0	0.0	0.0	0.0	0.0
    =#
    let   
        cap = VariableCapacity("input", mass, ub=5., unitsize=5.)
        # uc = UnitCommitment("input", 1., startup=0., shutdown=1.5, uptime=0.5, downtime=0.5, integer=true)
        uc = UnitCommitment("input", .5, startup=2., shutdown=0., uptime=0., downtime=1., startupratio = 0.5, shutdownratio = 1., integer=true)
        
        m = makecomp([cap, uc])
        
        # test: startup and shutdown + downtime
        @constraint(sim(m).model, _balance(m, :output, energy, collapse=false)[1] == 0.)

        set_objective(sim(m).model, MAX_SENSE, weighted_balance_sum(m, :input, energy))
        JuMP.set_silent(sim(m).model)
        JuMP.optimize!(sim(m).model)
        _m = _extract(m)
        # _uctable(_m)
        @test all(isapprox.(_balance(_m, :output, energy, collapse=false), [0., 0., 0.625, 1.25, 1.875, 2.5, 5., 5., 5., 0.], atol=1E-8)) # had to be patched due to numeric error after updating HiGHS
        @test all(isapprox.(_up(_m.behaviors[2]), [0., 0., 1., 1., 1., 1., 1., 1., 1., 0.], atol=1E-8))  # had to be patched due to numeric error after updating HiGHS
    end

    #=
    t	uc	st	sd	v	up	b
    1	0.0	0.0	0.0	0.0	0.0	0.0
    2	0.0	0.0	0.0	0.0	0.0	0.0
    3	0.0	0.0	0.0	0.0	0.0	0.0
    4	0.0	0.0	0.0	0.0	1.0	0.625
    5	0.0	0.0	0.0	0.0	1.0	1.25
    6	0.0	0.0	0.0	0.0	1.0	1.875
    7	1.0	1.0	1.0	0.0	1.0	2.5
    8	0.0	0.0	0.0	0.0	1.0	2.8125
    9	0.0	0.0	0.0	0.0	1.0	1.875
    10	0.0	0.0	0.0	0.0	1.0	0.9375
    =#
    let   
        cap = VariableCapacity("input", mass, ub=5., unitsize=5.)
        # uc = UnitCommitment("input", 1., startup=0., shutdown=1.5, uptime=0.5, downtime=0.5, integer=true)
        uc = UnitCommitment("input", 0.5, startup=2., shutdown=2., uptime=0., downtime=1., startupratio = 0.5, shutdownratio = 0.75, integer=true)
        
        m = makecomp([cap, uc])
        
        # test: startup and shutdown + downtime
        @constraint(sim(m).model, _balance(m, :output, energy, collapse=false)[1] == 0.)

        set_objective(sim(m).model, MAX_SENSE, weighted_balance_sum(m, :input, energy))
        JuMP.set_silent(sim(m).model)
        JuMP.optimize!(sim(m).model)
        _m = _extract(m)
        # _uctable(_m)
        @test all(isapprox.(_balance(_m, :output, energy, collapse=false), [0., 0., 0., 0.625, 1.25, 1.875, 2.5, 2.8125, 1.875, 0.9375]))
        @test all(isapprox.(_up(_m.behaviors[2]), [0., 0., 0., 1., 1., 1., 1., 1., 1., 1.], atol=1E-8))
    end
   

    @testset "Non-circular time" begin

        # The terminal commitment state must also be bounded by installed
        # capacity; there is no following minimum-downtime row on an open mesh
        # from which this bound could be inferred.
        let
            cap = VariableCapacity("input", mass, ub=10., unitsize=5., integer=true)
            uc = UnitCommitment("input", 0., integer=true)

            m = makecomp_opentime([cap, uc])
            cap_behavior = first(getbehaviors(m, Nosy.VariableCapacityBehavior))
            uc_behavior = first(getbehaviors(m, FleetUnitCommitmentBehavior))

            @constraint(sim(m).model, cap_behavior.val == 0.)
            set_objective(sim(m).model, MAX_SENSE, uc_behavior.state.data[end])
            JuMP.set_silent(sim(m).model)
            JuMP.optimize!(sim(m).model)

            @test JuMP.termination_status(sim(m).model) == JuMP.MOI.OPTIMAL
            @test iszero(JuMP.value(uc_behavior.state.data[end]))
            @test iszero(JuMP.value(uc_behavior.startup.data[end]))
        end

        # A unit completing startup is capped by startupratio at the endpoint.
        let
            cap = FixedCapacity("input", mass, 5., unitsize=5.)
            uc = UnitCommitment("input", 0.5, startup=1., startupratio=0.75, shutdownratio=1., integer=true)

            m = makecomp_opentime([cap, uc])
            uc_behavior = first(getbehaviors(m, FleetUnitCommitmentBehavior))
            flow = _balance(m, :input, mass, collapse=false)

            @constraint(sim(m).model, uc_behavior.state[2] == 0.)
            @constraint(sim(m).model, uc_behavior.state[3] == 1.)
            set_objective(sim(m).model, MAX_SENSE, flow[3])
            JuMP.set_silent(sim(m).model)
            JuMP.optimize!(sim(m).model)

            @test JuMP.termination_status(sim(m).model) == JuMP.MOI.OPTIMAL
            @test isapprox(JuMP.value(uc_behavior.startup.data[3]), 1.)
            @test isapprox(JuMP.value(flow[3]), 3.75)
        end

        # A unit beginning shutdown is capped by shutdownratio at the endpoint.
        let
            cap = FixedCapacity("input", mass, 5., unitsize=5.)
            uc = UnitCommitment("input", 0.5, shutdown=1., startupratio=1., shutdownratio=0.75, integer=true)

            m = makecomp_opentime([cap, uc])
            uc_behavior = first(getbehaviors(m, FleetUnitCommitmentBehavior))
            flow = _balance(m, :input, mass, collapse=false)

            @constraint(sim(m).model, uc_behavior.state[3] == 1.)
            @constraint(sim(m).model, uc_behavior.state[4] == 0.)
            set_objective(sim(m).model, MAX_SENSE, flow[3])
            JuMP.set_silent(sim(m).model)
            JuMP.optimize!(sim(m).model)

            @test JuMP.termination_status(sim(m).model) == JuMP.MOI.OPTIMAL
            @test isapprox(JuMP.value(uc_behavior.shutdown.data[3]), 1.)
            @test isapprox(JuMP.value(flow[3]), 3.75)
        end

        let
            cap = FixedCapacity("input", mass, 10., unitsize=5.)
            uc = UnitCommitment("input", 1., startup=0., shutdown=0., uptime=0., downtime=0., integer=true)

            m = makecomp_opentime([cap, uc])
            uc_behavior = m.behaviors[2]

            @constraint(sim(m).model, uc_behavior.state[1] == 0.)
            @constraint(sim(m).model, _balance(m, :output, energy, collapse=false)[nsteps(sim(m))] == 10.)

            set_objective(sim(m).model, MIN_SENSE, sum(_balance(m, :output, energy, collapse=false)))
            JuMP.set_silent(sim(m).model)
            JuMP.optimize!(sim(m).model)
            _m = _extract(m)
            _uc = _m.behaviors[2]

            @test all(_balance(_m, :output, energy, collapse=false) .== [0., 0., 0., 0., 0., 0., 0., 0., 0., 10.])
            @test all(_uc.state.data .== [0., 0., 0., 0., 0., 0., 0., 0., 0., 2.])
            @test all(_uc.startup.data .== [0., 0., 0., 0., 0., 0., 0., 0., 0., 2.])
            @test all(iszero.(_uc.shutdown.data))
            @test all(_up(_uc) .== [0., 0., 0., 0., 0., 0., 0., 0., 0., 2.])
        end

        let
            cap = FixedCapacity("input", mass, 10., unitsize=5.)
            uc = UnitCommitment("input", 1., startup=2., shutdown=0., uptime=0., downtime=0., integer=true)

            m = makecomp_opentime([cap, uc])
            uc_behavior = m.behaviors[2]

            @constraint(sim(m).model, uc_behavior.state[1] == 0.)
            @constraint(sim(m).model, _balance(m, :output, energy, collapse=false)[nsteps(sim(m))] == 10.)

            set_objective(sim(m).model, MIN_SENSE, sum(_balance(m, :output, energy, collapse=false)))
            JuMP.set_silent(sim(m).model)
            JuMP.optimize!(sim(m).model)
            _m = _extract(m)
            _uc = _m.behaviors[2]

            @test all(_balance(_m, :output, energy, collapse=false) .== [0., 0., 0., 0., 0., 0., 0., 0., 5., 10.])
            @test all(_uc.state.data .== [0., 0., 0., 0., 0., 0., 0., 0., 0., 2.])
            @test all(_uc.startup.data .== [0., 0., 0., 0., 0., 0., 0., 0., 0., 2.])
            @test all(iszero.(_uc.shutdown.data))
            @test all(_up(_uc) .== [0., 0., 0., 0., 0., 0., 0., 0., 2., 2.])
        end

        let
            cap = FixedCapacity("input", mass, 10., unitsize=5.)
            uc = UnitCommitment("input", 1., startup=0., shutdown=2., uptime=0., downtime=0., integer=true)

            m = makecomp_opentime([cap, uc])

            @constraint(sim(m).model, _balance(m, :output, energy, collapse=false)[1] == 10.)

            set_objective(sim(m).model, MIN_SENSE, sum(_balance(m, :output, energy, collapse=false)))
            JuMP.set_silent(sim(m).model)
            JuMP.optimize!(sim(m).model)
            _m = _extract(m)
            _uc = _m.behaviors[2]

            @test all(_balance(_m, :output, energy, collapse=false) .== [10., 5., 0., 0., 0., 0., 0., 0., 0., 0.])
            @test all(_uc.state.data .== [2., 0., 0., 0., 0., 0., 0., 0., 0., 0.])
            @test all(_uc.shutdown.data .== [2., 0., 0., 0., 0., 0., 0., 0., 0., 0.])
            @test all(_up(_uc) .== [2., 2., 0., 0., 0., 0., 0., 0., 0., 0.])
        end

    end


    # fleet commitment with irregular timesteps
    let
        irrmesh = TimeMesh([1//1, 1//1, 1//1, 1//1, 1//2, 1//2, 1//1, 1//1, 1//1, 1//1, 1//2, 1//2])

        function makecomp_irregular(vbehavior=[])
            s = Sim(Model(HiGHS.Optimizer), mesh=irrmesh)
            en = collect(1:nhours(s.mesh))   # nhours(= sum(weights))
            mc = MassCarrier("m", s, energy=en)
            ec = EnergyCarrier("e", s)
            d  = BasicConverter(mc, ec)
            return Component("comp", d, vbehavior)
        end

        let
            cap = VariableCapacity("input", mass, ub=5., unitsize=5.)
            uc  = UnitCommitment("input", 1., startup=2., shutdown=0., uptime=0., downtime=1.5, integer=true)

            m   = makecomp_irregular([cap, uc])

            @constraint(sim(m).model, _balance(m, :output, energy, collapse=false)[6] == 0.)

            set_objective(sim(m).model, MAX_SENSE, weighted_balance_sum(m, :input, energy))
            JuMP.set_silent(sim(m).model)
            JuMP.optimize!(sim(m).model)
            _m = _extract(m)

            @test all(isapprox.(_balance(_m, :output, energy, collapse=false),[5.0, 5.0, 5.0, 0.0, 0.0, 0.0, 0.0, 2.5, 5.0, 5.0, 5.0, 5.0]))
            @test all(_up(_m.behaviors[2]) .== [1.0, 1.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 1.0, 1.0])
        end

        let
            cap = VariableCapacity("input", mass, ub=5., unitsize=5.)
            uc  = UnitCommitment("input", 1., startup=0., shutdown=0., uptime=0., downtime=2., integer=true)

            m   = makecomp_irregular([cap, uc])

            @constraint(sim(m).model, _balance(m, :output, energy, collapse=false)[1] == 0.)

            set_objective(sim(m).model, MAX_SENSE, weighted_balance_sum(m, :input, energy))
            JuMP.set_silent(sim(m).model)
            JuMP.optimize!(sim(m).model)
            _m = _extract(m)

            @test all(isapprox.(_balance(_m, :output, energy, collapse=false),[0.0, 0.0, 0.0, 5.0, 5.0, 5.0, 5.0, 5.0, 5.0, 5.0, 5.0, 5.0]))
            @test all(_up(_m.behaviors[2]) .==  [0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0])
        end
    end

    # masking: startup blocked until step 4, switch should occur as soon as allowed
    let
        cap = FixedCapacity("input", mass, 10., unitsize=5.)
        mask = [false, false, false, true, true, true, true, true, true, true]
        uc = UnitCommitment("input", 1., startup=0., shutdown=0., uptime=0., downtime=0., integer=true,
            startupmask=mask, shutdownmask=[mask]
        )

        m = makecomp([cap, uc])

        # initial state: off
        @constraint(sim(m).model, m.behaviors[2].state[1] == 0.)

        set_objective(sim(m).model, MAX_SENSE, weighted_balance_sum(m, :input, energy))
        JuMP.set_silent(sim(m).model)
        JuMP.optimize!(sim(m).model)
        _m = _extract(m)

        @test all(_m.behaviors[2].startup[1:3] .== 0.)
        @test _m.behaviors[2].startup[4] == 2.
        @test all(_balance(_m, :output, energy, collapse=false) .== [0., 0., 0., 10., 10., 10., 10., 10., 10., 10.])
    end

    # masking: shutdown blocked until step 4, switch should occur as soon as allowed
    let
        cap = FixedCapacity("input", mass, 10., unitsize=5.)
        mask = [false, false, false, true, true, true, true, true, true, true]
        uc = UnitCommitment("input", 1., startup=0., shutdown=0., uptime=0., downtime=0., integer=true,
            shutdownmask=[mask]
        )

        m = makecomp([cap, uc])

        # initial state: on
        @constraint(sim(m).model, m.behaviors[2].state[1] == 2.)

        set_objective(sim(m).model, MIN_SENSE, weighted_balance_sum(m, :input, energy))
        JuMP.set_silent(sim(m).model)
        JuMP.optimize!(sim(m).model)
        _m = _extract(m)

        @test all(_m.behaviors[2].shutdown[1:3] .== 0.)
        @test _m.behaviors[2].shutdown[4] == 2.
        @test all(_balance(_m, :output, energy, collapse=false) .== [10., 10., 10., 10., 0., 0., 0., 0., 0., 0.])
    end

    @testset "Fleet unit commitment from ini" begin

        # FromIni fixes the discrete UC trajectory from an extracted model and
        # reuses the rebuilt component's dispatch variable.
        function make_fromini(minratio)
            cap = FixedCapacity("input", mass, 10., unitsize=5.)
            uc = UnitCommitment("input", minratio, startup=1., shutdown=1., uptime=0., downtime=0., integer=true)
            m = makecomp([cap, uc])
            @constraint(sim(m).model, _balance(m, :output, energy, collapse=false)[1] == 0.)
            set_objective(sim(m).model, MAX_SENSE, weighted_balance_sum(m, :input, energy))
            JuMP.set_silent(sim(m).model)
            JuMP.optimize!(sim(m).model)
            _m = _extract(m)
            return UnitCommitment(_m.behaviors[2]), _m
        end

        let
            ucfromini, ini = make_fromini(0.5)

            @test ucfromini isa Nosy.FleetUnitCommitmentFromIni
            @test ucfromini.pname == "input"
            @test ucfromini.minratio == 0.5
            @test ucfromini.startup == 1.
            @test ucfromini.shutdown == 1.
            @test ucfromini.downtime == [0.]
            @test ucfromini.series_startup === ini.behaviors[2].startup
            @test ucfromini.series_shutdown === ini.behaviors[2].shutdown
            @test ucfromini.series_shutdown_selector === ini.behaviors[2].shutdownselector
            @test ucfromini.series_state === ini.behaviors[2].state

            # FromIni is only meaningful if the rebuilt component has a
            # capacity on the committed port; otherwise unit count and flow
            # reconstruction are undefined.
            @test_throws AssertionError makecomp([ucfromini])

            # The capacity must expose unitsize: FromIni reuses fixed unit
            # counts from the previous solve, so capacity alone is ambiguous.
            @test_throws AssertionError makecomp([FixedCapacity("input", mass, 10.), ucfromini])

            # Composed capacities do not provide a single-port unit size for
            # the committed port, and would make the fixed UC trajectory
            # ambiguous across ports.
            @test_throws AssertionError makecomp([FixedComposedCapacity(["input", "output"], energy, 10.), ucfromini])

            rebuilt = makecomp([FixedCapacity("input", mass, 10., unitsize=5.), ucfromini])
            rebuilduc = rebuilt.behaviors[2]
            @test rebuilduc isa Nosy.FleetUnitCommitmentFromIniBehavior
            @test rebuilduc.startup === ucfromini.series_startup
            @test rebuilduc.shutdown === ucfromini.series_shutdown
            @test rebuilduc.shutdownselector === ucfromini.series_shutdown_selector
            @test rebuilduc.state === ucfromini.series_state
            @test nvariables(sim(rebuilt)) == 10
            @test all(_up(rebuilduc) .== _up(ini.behaviors[2]))
        end

        let
            ucfromini, ini = make_fromini(1.0)
            rebuilt = makecomp([FixedCapacity("input", mass, 10., unitsize=5.), ucfromini])
            rebuilduc = rebuilt.behaviors[2]

            @test rebuilduc isa Nosy.FleetUnitCommitmentFromIniBehavior
            @test nvariables(sim(rebuilt)) == 10
            JuMP.set_silent(sim(rebuilt).model)
            JuMP.optimize!(sim(rebuilt).model)
            @test all(isapprox.(JuMP.value.(rebuilduc.variable.data), 0.; atol=1E-8))
            @test all(_up(rebuilduc) .== _up(ini.behaviors[2]))
        end
    end
end

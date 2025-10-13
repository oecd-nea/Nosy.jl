using Nosy: mass, energy
using Nosy: Sim, TimeMesh, nvariables, nconstraints, sim, nsteps, nhours
using Nosy: VariableCapacity, FixedCapacity, capacity
using Nosy: UnitCommitment, FleetUnitCommitmentBehavior, _up
using Nosy: getbehaviors
using Nosy: BasicConverter
using Nosy: MassCarrier, EnergyCarrier
using Nosy: mass, energy
using Nosy: ProfileSource
using Nosy: Component
using Nosy: _balance, _extract
using Nosy: nvariables, nconstraints
using JuMP: Model, AffExpr, lower_bound, upper_bound, has_lower_bound, has_upper_bound, set_objective, MIN_SENSE, MAX_SENSE, @constraint
import JuMP
using ArgCheck: ArgumentError
import HiGHS
using DataFrames

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

    function makecomp(vbehavior=[])
        s = tsim()    
        mc = MassCarrier("m", s, energy=[1,2,3,4,5])
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
        df[!,"sd1"] = uc.shutdown1.data
        df[!,"sd2"] = uc.shutdown2.data
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

    #=
        t	uc	st	sd	v	up	b
        1	0.0	0.0	0.0	0.0	0.0	0.0
        2	2.0	2.0	2.0	5.0	2.0	10.0
        3	0.0	0.0	0.0	0.0	0.0	0.0
        4	2.0	2.0	0.0	5.0	2.0	10.0
        5	2.0	0.0	0.0	5.0	2.0	10.0
        6	2.0	0.0	0.0	5.0	2.0	10.0
        7	2.0	0.0	0.0	5.0	2.0	10.0
        8	2.0	0.0	0.0	5.0	2.0	10.0
        9	2.0	0.0	0.0	5.0	2.0	10.0
        10	2.0	0.0	2.0	5.0	2.0	10.0
    =#
    let   
        cap = FixedCapacity("input", mass, 10., unitsize=5.)
        uc = UnitCommitment("input", 0.5, startup=0, shutdown=0, uptime=0, downtime=0, integer=false)
        
        m = makecomp([cap, uc])
        
        # variables
        # 10 for converter
        # 0 for capacity (fixed)
        # 40 for UC (startup, shutdown, state, variable). NB minratio is >0 so variable flow is indeed associated w a variable
        @test nvariables(sim(m)) == 50
        
        # constraints
        # 10 for converter lower bound
        # 10 for capacity
        # 40 for uc attributes lower bounds (startup, shutdown, state, variable)
        # 40 for uc attributes upper bounds (startup, shutdown, state, variable)
        # 10 for uc switch constraint
        # 10 for uc variable flow constraint
        # 0 for uc units constraint # currently deactivated
        # 0 for uc min uptime constraint (uptime=0)
        # 10 for uc min downtime constraint (downtime=0 but startup and shutdown are actually included and take at least one step each - even when duration is 0)
        # 10 for uc flow constraint
        # 10 for shutdown <= uc constraint
        @test nconstraints(sim(m)) == 150
        
        # test: maximum capacity can be reached, even with constraint of 0 flow at some point
        # no startup / shutdown constraints
        @constraint(sim(m).model, _balance(m, :output, energy, collapse=false)[1] == 0.)
        @constraint(sim(m).model, _balance(m, :output, energy, collapse=false)[3] == 0.)
        # max should be reached in at step 2 and steps 4:10
        set_objective(sim(m).model, MAX_SENSE, _balance(m, :input, energy))
        JuMP.set_silent(sim(m).model)
        JuMP.optimize!(sim(m).model)
        _m = _extract(m)
        # _uctable(_m)
        @test all(_balance(_m, :output, energy, collapse=false) .== [0., 10., 0., 10., 10., 10., 10., 10., 10., 10.])
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
        set_objective(sim(m).model, MAX_SENSE, _balance(m, :input, energy))
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
        
        set_objective(sim(m).model, MAX_SENSE, _balance(m, :input, energy))
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
    5	2.0	2.0	0.0	5.0	2.0	10.0
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
        @constraint(sim(m).model, _balance(m, :output, energy, collapse=false)[5] == 10.)

        set_objective(sim(m).model, MIN_SENSE, _balance(m, :input, energy))
        JuMP.set_silent(sim(m).model)
        JuMP.optimize!(sim(m).model)
        _m = _extract(m)
        # _uctable(_m)
        @test all(_balance(_m, :output, energy, collapse=false) .== [0., 0., 0., 2.5, 10., 5., 5., 2.5, 0., 0.])
        @test all(_up(_m.behaviors[2]) .== [0., 0., 0., 2., 2., 2., 2., 2., 0., 0.])
    end

    #=
    t	uc	st	sd	v	up	b
    1	2.0	0.0	0.0	5.0	2.0	10.0
    2	2.0	0.0	0.0	5.0	2.0	10.0
    3	2.0	0.0	2.0	5.0	2.0	10.0
    4	0.0	0.0	0.0	0.0	2.0	2.5
    5	0.0	0.0	0.0	0.0	0.0	0.0
    6	0.0	0.0	0.0	0.0	0.0	0.0
    7	0.0	0.0	0.0	0.0	0.0	0.0
    8	0.0	0.0	0.0	0.0	2.0	2.5
    9	2.0	2.0	0.0	5.0	2.0	10.0
    10	2.0	0.0	0.0	5.0	2.0	10.0
    =#
    let   
        cap = FixedCapacity("input", mass, 10., unitsize=5.)
        uc = UnitCommitment("input", 0.5, startup=1, shutdown=1, uptime=0, downtime=1, integer=true)
        
        m = makecomp([cap, uc])
        
        # test: startup and shutdown + downtime
        @constraint(sim(m).model, _balance(m, :output, energy, collapse=false)[3] == 10.)
        @constraint(sim(m).model, _balance(m, :output, energy, collapse=false)[5] == 0.)

        set_objective(sim(m).model, MAX_SENSE, _balance(m, :input, energy))
        JuMP.set_silent(sim(m).model)
        JuMP.optimize!(sim(m).model)
        _m = _extract(m)
        # _uctable(_m)
        @test all(_balance(_m, :output, energy, collapse=false) .== [10., 10., 10., 2.5, 0., 0., 0., 2.5, 10., 10.])
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

        set_objective(sim(m).model, MAX_SENSE, _balance(m, :input, energy))
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

        set_objective(sim(m).model, MAX_SENSE, _balance(m, :input, energy))
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
    3	2.0	2.0	2.0	5.0	2.0	10.0
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
        # 40 for UC (startup, shutdown, state, variable). NB minratio is >0 so variable flow is indeed associated w a variable
        @test nvariables(sim(m)) == 51
        
        # constraints
        # 10 for converter lower bound
        # 2 for capacity lb and ub
        # 10 for capacity
        # 40 for uc attributes lower bounds (startup, shutdown, state, variable)
        # 40 for uc attributes upper bounds (startup, shutdown, state, variable)
        # 30 for uc attributes integer constraint (startup, shutdown, state)
        # 10 for uc switch constraint
        # 10 for uc variable flow constraint
        # 0 for uc units constraint # currently deactivated
        # 0 for uc min uptime constraint (uptime=0)
        # 10 for uc min downtime constraint
        # 10 for uc flow constraint
        # 10 for shutdown <= uc constraint
        @test nconstraints(sim(m)) == 182

        # test: startup and shutdown + downtime
        @constraint(sim(m).model, _balance(m, :output, energy, collapse=false)[3] == 10.)
        @constraint(sim(m).model, _balance(m, :output, energy, collapse=false)[5] == 0.)

        set_objective(sim(m).model, MAX_SENSE, _balance(m, :input, energy))
        JuMP.set_silent(sim(m).model)
        JuMP.optimize!(sim(m).model)
        _m = _extract(m)
        # _uctable(_m)
        @test all(_balance(_m, :output, energy, collapse=false) .== [2.5, 3.75, 10., 2.5, 0., 0., 0., 0., 0., 1.25])
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

        set_objective(sim(m).model, MAX_SENSE, _balance(m, :input, energy))
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

        set_objective(sim(m).model, MIN_SENSE, _balance(m, :input, energy))
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

        set_objective(sim(m).model, MIN_SENSE, _balance(m, :input, energy))
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

        set_objective(sim(m).model, MIN_SENSE, _balance(m, :input, energy))
        JuMP.set_silent(sim(m).model)
        JuMP.optimize!(sim(m).model)
        _m = _extract(m)
        # _uctable(_m)
        @test all(isapprox.(_balance(_m, :output, energy, collapse=false), [10., 10., 5., 0., 0., 0., 0., 2.5, 5., 7.5]))
        @test all(_up(_m.behaviors[2]) .== [2., 2., 2., 0., 0., 0., 0., 2., 2., 2.])
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

        set_objective(sim(m).model, MAX_SENSE, _balance(m, :input, energy))
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

        set_objective(sim(m).model, MAX_SENSE, _balance(m, :input, energy))
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
    6	1.0	1.0	0.0	0.0	1.0	5.0
    7	1.0	0.0	0.0	0.0	1.0	5.0
    8	1.0	0.0	0.0	0.0	1.0	5.0
    9	1.0	0.0	1.0	0.0	1.0	5.0
    10	0.0	0.0	0.0	0.0	0.0	0.0
    =#
    let   
        cap = VariableCapacity("input", mass, ub=5., unitsize=5.)
        # uc = UnitCommitment("input", 1., startup=0., shutdown=1.5, uptime=0.5, downtime=0.5, integer=true)
        uc = UnitCommitment("input", .5, startup=2., shutdown=0., uptime=0., downtime=1., startupratio = 0.5, shutdownratio = 1., integer=true)
        
        m = makecomp([cap, uc])
        
        # test: startup and shutdown + downtime
        @constraint(sim(m).model, _balance(m, :output, energy, collapse=false)[1] == 0.)

        set_objective(sim(m).model, MAX_SENSE, _balance(m, :input, energy))
        JuMP.set_silent(sim(m).model)
        JuMP.optimize!(sim(m).model)
        _m = _extract(m)
        # _uctable(_m)
        @test all(isapprox.(_balance(_m, :output, energy, collapse=false), [0., 0., 0.625, 1.25, 1.875, 5., 5., 5., 5., 0.]))
        @test all(_up(_m.behaviors[2]) .== [0., 0., 1., 1., 1., 1., 1., 1., 1., 0.])
    end

    #=
    t	uc	st	sd	v	up	b
    1	0.0	0.0	0.0	0.0	0.0	0.0
    2	0.0	0.0	0.0	0.0	0.0	0.0
    3	0.0	0.0	0.0	0.0	0.0	0.0
    4	0.0	0.0	0.0	0.0	1.0	0.625
    5	0.0	0.0	0.0	0.0	1.0	1.25
    6	0.0	0.0	0.0	0.0	1.0	1.875
    7	1.0	1.0	1.0	2.5	1.0	5.0
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

        set_objective(sim(m).model, MAX_SENSE, _balance(m, :input, energy))
        JuMP.set_silent(sim(m).model)
        JuMP.optimize!(sim(m).model)
        _m = _extract(m)
        # _uctable(_m)
        @test all(isapprox.(_balance(_m, :output, energy, collapse=false), [0., 0., 0., 0.625, 1.25, 1.875, 5., 2.8125, 1.875, 0.9375]))
        @test all(_up(_m.behaviors[2]) .== [0., 0., 0., 1., 1., 1., 1., 1., 1., 1.])
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

            set_objective(sim(m).model, MAX_SENSE, _balance(m, :input, energy))
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

            set_objective(sim(m).model, MAX_SENSE, _balance(m, :input, energy))
            JuMP.set_silent(sim(m).model)
            JuMP.optimize!(sim(m).model)
            _m = _extract(m)

            @test all(isapprox.(_balance(_m, :output, energy, collapse=false),[0.0, 0.0, 0.0, 5.0, 5.0, 5.0, 5.0, 5.0, 5.0, 5.0, 5.0, 5.0]))
            @test all(_up(_m.behaviors[2]) .==  [0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0])
        end
    end
end

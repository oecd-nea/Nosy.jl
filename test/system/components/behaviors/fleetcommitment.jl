using Nosy: mass, energy
using Nosy: Sim, TimeMesh, nvariables, nconstraints, sim
using Nosy: VariableCapacity, FixedCapacity, capacity
using Nosy: UnitCommitment, FleetUnitCommitmentBehavior
using Nosy: BasicConverter
using Nosy: MassCarrier, EnergyCarrier
using Nosy: mass, energy
using Nosy: ProfileSource
using Nosy: Component
using Nosy: balance, _extract
using Nosy: nvariables, nconstraints
import JuMP: Model, AffExpr, lower_bound, upper_bound, has_lower_bound, has_upper_bound, set_objective, MIN_SENSE, MAX_SENSE, @constraint
using ArgCheck: ArgumentError
import HiGHS

@testset "Fleet unit commitment" begin

    tsim() = Sim(TimeMesh(fill(1//2, 10)), Model(HiGHS.Optimizer))

    function makecomp(vbehavior=[])
        s = tsim()    
        mc = MassCarrier("m", s, energy=[1,2,3,4,5])
        ec = EnergyCarrier("e", s)
        d = BasicConverter(mc, ec)
        c = Component("comp", d, vbehavior)
        return c
    end

    @test_throws ArgumentError UnitCommitment("input", -0.5) # negative minratio not allowed
    @test_throws ArgumentError UnitCommitment("input", 0.5, startup=-1) # negative startup not allowed
    @test_throws ArgumentError UnitCommitment("input", 0.5, shutdown=-1) # negative shutdown not allowed
    @test_throws ArgumentError UnitCommitment("input", 0.5, uptime=-1) # negative uptime not allowed
    @test_throws ArgumentError UnitCommitment("input", 0.5, downtime=-1) # negative downtime not allowed


    let   
        uc = UnitCommitment("input", 0.5, startup=0, shutdown=0, uptime=0, downtime=0, integer=false)
             
        # unit commitment requires capacity
        @test_throws AssertionError m = makecomp([uc])

    end

    let   
        cap = FixedCapacity("input", mass, 10., unitsize=5.)
        uc = UnitCommitment("input", 0.5, startup=0, shutdown=0, uptime=0, downtime=0, integer=false)
        
        m = makecomp([cap, uc])
        
        # check correct dispatch into FleetUnitCommitmentBehavior
        @test m.behaviors[2] isa FleetUnitCommitmentBehavior

    end

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
        # 0 for uc min downtime constraint (downtime=0)
        # 10 for uc flow constraint
        @test nconstraints(sim(m)) == 130
        
        # test: maximum capacity can be reached, even with constraint of 0 flow at some point
        # no startup / shutdown constraints
        @constraint(sim(m).model, balance(m, :output, energy, collapse=false)[1] == 0.)
        @constraint(sim(m).model, balance(m, :output, energy, collapse=false)[3] == 0.)
        # max should be reached in at step 2 and steps 4:10
        set_objective(sim(m).model, MAX_SENSE, balance(m, :output, energy))
        JuMP.set_silent(sim(m).model)
        JuMP.optimize!(sim(m).model)
        _m = _extract(m)

        @test all(balance(_m, :output, energy, collapse=false)[i] == 10. for i in (2,4:10...))
    end

    let   
        cap = FixedCapacity("input", mass, 10., unitsize=5.)
        uc = UnitCommitment("input", 0.5, startup=3, shutdown=2, uptime=0, downtime=0, integer=false)
        
        m = makecomp([cap, uc])
        
        # test: startup and shutdown
        @constraint(sim(m).model, balance(m, :output, energy, collapse=false)[1] == 0.)
        @constraint(sim(m).model, balance(m, :output, energy, collapse=false)[5] == 0.)
        # maximum can't be reached: no time because of startup / shutdown time
        # output should always stay at 0
        set_objective(sim(m).model, MAX_SENSE, balance(m, :output, energy))
        JuMP.set_silent(sim(m).model)
        JuMP.optimize!(sim(m).model)
        _m = _extract(m)

        @test all(balance(_m, :output, energy, collapse=false) .== 0.)
    end

    let   
        cap = FixedCapacity("input", mass, 10., unitsize=5.)
        uc = UnitCommitment("input", 0.5, startup=1, shutdown=1, uptime=0, downtime=0, integer=false)
        
        m = makecomp([cap, uc])
        
        # test: startup and shutdown
        @constraint(sim(m).model, balance(m, :output, energy, collapse=false)[5] == 0.)
        
        set_objective(sim(m).model, MAX_SENSE, balance(m, :output, energy))
        JuMP.set_silent(sim(m).model)
        JuMP.optimize!(sim(m).model)
        _m = _extract(m)

        @test all(balance(_m, :output, energy, collapse=false) .== [10., 10., 10., 2.5, 0., 2.5, 10., 10., 10., 10.])
    end

    let   
        cap = FixedCapacity("input", mass, 10., unitsize=5.)
        uc = UnitCommitment("input", 0.5, startup=1, shutdown=1, uptime=1, downtime=0, integer=true)
        
        m = makecomp([cap, uc])
        
        # test: min uptime
        @constraint(sim(m).model, balance(m, :output, energy, collapse=false)[3] == 0.)
        @constraint(sim(m).model, balance(m, :output, energy, collapse=false)[5] == 10.)

        set_objective(sim(m).model, MIN_SENSE, balance(m, :output, energy))
        JuMP.set_silent(sim(m).model)
        JuMP.optimize!(sim(m).model)
        _m = _extract(m)

        @test all(balance(_m, :output, energy, collapse=false) .== [0., 0., 0., 2.5, 10., 5., 5., 2.5, 0., 0.])
    end

    let   
        cap = FixedCapacity("input", mass, 10., unitsize=5.)
        uc = UnitCommitment("input", 0.5, startup=1, shutdown=1, uptime=0, downtime=1, integer=true)
        
        m = makecomp([cap, uc])
        
        # test: startup and shutdown + downtime
        @constraint(sim(m).model, balance(m, :output, energy, collapse=false)[3] == 10.)
        @constraint(sim(m).model, balance(m, :output, energy, collapse=false)[5] == 0.)

        set_objective(sim(m).model, MAX_SENSE, balance(m, :output, energy))
        JuMP.set_silent(sim(m).model)
        JuMP.optimize!(sim(m).model)
        _m = _extract(m)

        @test all(balance(_m, :output, energy, collapse=false) .== [10., 10., 10., 2.5, 0., 0., 0., 2.5, 10., 10.])
    end


    let   
        cap = FixedCapacity("input", mass, 10., unitsize=5.)
        uc = UnitCommitment("input", 1., startup=2, shutdown=1, uptime=0, downtime=2, integer=true)
        
        m = makecomp([cap, uc])
        
        # test: startup and shutdown + downtime
        @constraint(sim(m).model, balance(m, :output, energy, collapse=false)[3] == 10.)
        @constraint(sim(m).model, balance(m, :output, energy, collapse=false)[5] == 0.)

        set_objective(sim(m).model, MAX_SENSE, balance(m, :output, energy))
        JuMP.set_silent(sim(m).model)
        JuMP.optimize!(sim(m).model)
        _m = _extract(m)
    
        @test all(balance(_m, :output, energy, collapse=false) .== [5., 7.5, 10., 5., 0., 0., 0., 0., 0., 2.5])
    end
    

    # compatibility with variable capacity (no variable flow)
    let   
        cap = VariableCapacity("input", mass, ub=10., unitsize=5.)
        uc = UnitCommitment("input", 1., startup=2, shutdown=1, uptime=0, downtime=2, integer=true)
        
        m = makecomp([cap, uc])
        
        # test: startup and shutdown + downtime
        @constraint(sim(m).model, balance(m, :output, energy, collapse=false)[3] == 10.)
        @constraint(sim(m).model, balance(m, :output, energy, collapse=false)[5] == 0.)

        set_objective(sim(m).model, MAX_SENSE, balance(m, :output, energy))
        JuMP.set_silent(sim(m).model)
        JuMP.optimize!(sim(m).model)
        _m = _extract(m)

        @test all(balance(_m, :output, energy, collapse=false) .== [5., 7.5, 10., 5., 0., 0., 0., 0., 0., 2.5])
    end

    # compatibility with variable capacity (with variable flow)
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
        # 10 for uc min downtime constraint (downtime=0)
        # 10 for uc flow constraint
        @test nconstraints(sim(m)) == 172

        # test: startup and shutdown + downtime
        @constraint(sim(m).model, balance(m, :output, energy, collapse=false)[3] == 10.)
        @constraint(sim(m).model, balance(m, :output, energy, collapse=false)[5] == 0.)
        # profile should be V-shaped around step 5
        # profile @ step 3 constraints non-zero @ step 4 => step 6 should be 0
        # there should be 2 steps at zero

        set_objective(sim(m).model, MAX_SENSE, balance(m, :output, energy))
        JuMP.set_silent(sim(m).model)
        JuMP.optimize!(sim(m).model)
        _m = _extract(m)

        @test all(balance(_m, :output, energy, collapse=false) .== [2.5, 3.75, 10., 2.5, 0., 0., 0., 0., 0., 1.25])
    end

end
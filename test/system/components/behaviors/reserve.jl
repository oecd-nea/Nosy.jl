using Nosy: energy, mass
using Nosy: Sim, TimeMesh, sim, nsteps
using Nosy: FixedCapacity, UnitCommitment, Ramping
using Nosy: ReserveUp, ReserveDown, ReserveBehavior, getbehaviors
using Nosy: EnergyCarrier, MassCarrier
using Nosy: DispatchableSource, BasicStorage, ProfileSource, BasicConverter
using Nosy: Component
using Nosy: _balance, _extract, capacity
using Nosy: FleetUnitCommitmentBehavior, _su, _sd, _state, _com, _var
using JuMP: Model, set_objective, MAX_SENSE, MIN_SENSE, @constraint
using ArgCheck: ArgumentError
using Test
import HiGHS
import JuMP

@testset "Reserve" begin

    tsim() = Sim(Model(HiGHS.Optimizer), mesh=TimeMesh(fill(1//2, 4)))

    # helpers: reserve behavior by sense
    upreserve(c) = first([b for b in getbehaviors(c, ReserveBehavior) if b.rsense == :up])
    downreserve(c) = first([b for b in getbehaviors(c, ReserveBehavior) if b.rsense == :down])

    # ReserveUp on input port for Storage with sense: :down (charge reduction)
    let
        s = tsim()
        ec = EnergyCarrier("e", s)
        c = Component("sto", BasicStorage(ec), [
            FixedCapacity("output", energy, 3.0),
            FixedCapacity("input", energy, 2.0),
            FixedCapacity("level", energy, 100.0),
            ReserveUp("test", "input", :down, 1.0; modifier=energy)  # charge reduction
        ])
        bs = [b for b in getbehaviors(c, ReserveBehavior) if b.rsense == :up]
        @test length(bs) == 1
        @test bs[1].data.pname == "input"
        @test bs[1].data.sense == :down
    end

    # ReserveUp not allowed with "discharge" port name (port doesn't exist)
    let
        s = tsim()
        ec = EnergyCarrier("e", s)
        @test_throws ArgumentError Component("sto", BasicStorage(ec), [
            FixedCapacity("output", energy, 3.0),
            ReserveUp("test", "discharge", :up, 1.0; modifier=energy)
        ])
    end

    # ReserveUp not compatible with ProfileSource
    let
        s = tsim()
        ec = EnergyCarrier("e", s)
        p = ProfileSource(ec, ones(Float64, nsteps(s)); cutoff=1.0)
        @test_throws ArgumentError Component("pv", p, [ReserveUp("test", "output", :up, 1.0; modifier=energy)])
    end

    # capacity constraint limits reserve to available headroom
    let
        s = tsim()
        ec = EnergyCarrier("e", s)
        c = Component("gen", DispatchableSource(ec), [
            FixedCapacity("output", energy, 10.0),
            ReserveUp("test", "output", :up, 1.0; modifier=energy)
        ])
        b = upreserve(c)
        
        @constraint(sim(c).model, _balance(c, :output, energy, collapse=false)[1] == 3.0)
        @constraint(sim(c).model, _balance(c, :output, energy, collapse=false)[2] == 3.0)
        set_objective(sim(c).model, MAX_SENSE, b.r.data[1])
        JuMP.set_silent(sim(c).model)
        JuMP.optimize!(sim(c).model)
        
        _c = _extract(c)
        r_val = JuMP.value.(b.r.data[1])
        @test isapprox(r_val, 7.0)
    end

    # ramping constraint limits reserve deployment rate
    let
        s = tsim()
        ec = EnergyCarrier("e", s)
        c = Component("gen", DispatchableSource(ec), [
            FixedCapacity("output", energy, 10.0),
            Ramping("output", :up, 6.0; modifier=energy),
            ReserveUp("test", "output", :up, 1.0; modifier=energy)
        ])
        b = upreserve(c)
        
        @constraint(sim(c).model, _balance(c, :output, energy, collapse=false)[1] == 0.0)
        @constraint(sim(c).model, _balance(c, :output, energy, collapse=false)[2] == 0.0)
        set_objective(sim(c).model, MAX_SENSE, b.r.data[1])
        JuMP.set_silent(sim(c).model)
        JuMP.optimize!(sim(c).model)
        
        r_val = JuMP.value.(b.r.data[1])
        @test isapprox(r_val, 3.0)
    end


    # charge reduction reserve is limited by available capacity to charge
    let
        s = tsim()
        ec = EnergyCarrier("e", s)
        c = Component("sto", BasicStorage(ec), [
            FixedCapacity("output", energy, 10.0),
            FixedCapacity("input", energy, 5.0),
            FixedCapacity("level", energy, 100.0),
            Ramping("input", :down, 2.0; modifier=energy),
            ReserveUp("test", "input", :down, 1.0; modifier=energy)
        ])
        b = upreserve(c)
        
        @constraint(sim(c).model, _balance(c, :input, energy, collapse=false)[1] == 3.0)
        @constraint(sim(c).model, _balance(c, :level, energy, collapse=false)[1] == 80.0)
        set_objective(sim(c).model, MAX_SENSE, b.r.data[1])
        JuMP.set_silent(sim(c).model)
        JuMP.optimize!(sim(c).model)
        
        _c = _extract(c)
        r_val = JuMP.value.(b.r.data[1])
        @test r_val <= 3.0
    end

    # ReserveDown on input port for Storage with sense: :up (charge increase)
    let
        s = tsim()
        ec = EnergyCarrier("e", s)
        c = Component("sto", BasicStorage(ec), [
            FixedCapacity("output", energy, 3.0),
            FixedCapacity("input", energy, 2.0),
            FixedCapacity("level", energy, 100.0),
            ReserveDown("test", "input", :up, 1.0; modifier=energy)  # charge increase
        ])
        bs = [b for b in getbehaviors(c, ReserveBehavior) if b.rsense == :down]
        @test length(bs) == 1
        @test bs[1].data.pname == "input"
        @test bs[1].data.sense == :up
    end

    # ReserveDown not allowed with "discharge" port name (port doesn't exist)
    let
        s = tsim()
        ec = EnergyCarrier("e", s)
        @test_throws ArgumentError Component("sto", BasicStorage(ec), [
            FixedCapacity("output", energy, 3.0),
            ReserveDown("test", "discharge", :down, 1.0; modifier=energy)
        ])
    end

    # ReserveDown not compatible with ProfileSource
    let
        s = tsim()
        ec = EnergyCarrier("e", s)
        p = ProfileSource(ec, ones(Float64, nsteps(s)); cutoff=1.0)
        @test_throws ArgumentError Component("pv", p, [ReserveDown("test", "output", :down, 1.0; modifier=energy)])
    end

    # capacity constraint limits reserve to available flow (downward reserve: r <= flow)
    let
        s = tsim()
        ec = EnergyCarrier("e", s)
        c = Component("gen", DispatchableSource(ec), [
            FixedCapacity("output", energy, 10.0),
            ReserveDown("test", "output", :down, 1.0; modifier=energy)
        ])
        b = downreserve(c)
        
        @constraint(sim(c).model, _balance(c, :output, energy, collapse=false)[1] == 7.0)
        @constraint(sim(c).model, _balance(c, :output, energy, collapse=false)[2] == 7.0)
        set_objective(sim(c).model, MAX_SENSE, b.r.data[1])
        JuMP.set_silent(sim(c).model)
        JuMP.optimize!(sim(c).model)
        
        _c = _extract(c)
        r_val = JuMP.value.(b.r.data[1])
        @test isapprox(r_val, 7.0)
    end

    # ramping constraint limits reserve deployment rate
    let
        s = tsim()
        ec = EnergyCarrier("e", s)
        c = Component("gen", DispatchableSource(ec), [
            FixedCapacity("output", energy, 10.0),
            Ramping("output", :down, 6.0; modifier=energy),
            ReserveDown("test", "output", :down, 1.0; modifier=energy)
        ])
        b = downreserve(c)
        
        @constraint(sim(c).model, _balance(c, :output, energy, collapse=false)[1] == 10.0)
        @constraint(sim(c).model, _balance(c, :output, energy, collapse=false)[2] == 10.0)
        set_objective(sim(c).model, MAX_SENSE, b.r.data[1])
        JuMP.set_silent(sim(c).model)
        JuMP.optimize!(sim(c).model)
        
        r_val = JuMP.value.(b.r.data[1])
        @test isapprox(r_val, 3.0)
    end

    # charge increase reserve is limited by available capacity to charge
    let
        s = tsim()
        ec = EnergyCarrier("e", s)
        c = Component("sto", BasicStorage(ec), [
            FixedCapacity("output", energy, 10.0),
            FixedCapacity("input", energy, 5.0),
            FixedCapacity("level", energy, 100.0),
            Ramping("input", :up, 2.0; modifier=energy),
            ReserveDown("test", "input", :up, 1.0; modifier=energy)
        ])
        b = downreserve(c)
        
        @constraint(sim(c).model, _balance(c, :input, energy, collapse=false)[1] == 3.0)
        @constraint(sim(c).model, _balance(c, :level, energy, collapse=false)[1] == 20.0)
        set_objective(sim(c).model, MAX_SENSE, b.r.data[1])
        JuMP.set_silent(sim(c).model)
        JuMP.optimize!(sim(c).model)
        
        _c = _extract(c)
        r_val = JuMP.value.(b.r.data[1])
        level_val = JuMP.value.(_balance(_c, :level, energy, collapse=false)[1])
        @test r_val <= 0.9 * (100.0 - level_val) / 1.0
    end

    # Reserve with unit commitment (edge cases)
    tsim10() = Sim(Model(HiGHS.Optimizer), mesh=TimeMesh(fill(1//2, 10)))
    function makecomp(vbehavior=[])
        s = tsim10()
        mc = MassCarrier("m", s, energy=[1,2,3,4,5])
        ec = EnergyCarrier("e", s)
        d = BasicConverter(mc, ec)
        return Component("gen", d, vbehavior)
    end

    # UC + Reserve: fix the UC port ("input") flow directly on the mass carrier (not output energy).
    # Unit off (state=0): upward reserve must be 0 when r_fast is also 0 (step length < startup duration)
    let
        c = makecomp([
            FixedCapacity("input", mass, 10.0, unitsize=5.0),
            UnitCommitment("input", 0.5, startup=1, shutdown=1, uptime=0, downtime=0, integer=false),
            Ramping("input", :up, 20.0; modifier=mass),
            Ramping("input", :down, 20.0; modifier=mass),
            ReserveUp("test", "input", :up, 1.0; modifier=mass),
        ])
        b = first(getbehaviors(c, ReserveBehavior))
        @constraint(sim(c).model, _balance(c, :input, mass, collapse=false).data .== 0)
        set_objective(sim(c).model, MAX_SENSE, sum(b.r.data))
        JuMP.set_silent(sim(c).model)
        JuMP.optimize!(sim(c).model)
        r_vals = JuMP.value.(b.r.data)
        # dt=0.5h < startup=1h => r_fast=0; state=0 => r_online=0 => r=0
        @test all(isapprox.(r_vals, 0.0; atol=1e-6))
        @test all(isapprox.(JuMP.value.(b.r_fast.data), 0.0; atol=1e-6))
    end

    # Unit on, not maxed: r_online = headroom from on unit. 1 unit (state=1): capacity 5, flow=3 -> headroom 2
    let
        c = makecomp([
            FixedCapacity("input", mass, 10.0, unitsize=5.0),
            UnitCommitment("input", 0.5, startup=0, shutdown=0, uptime=0, downtime=0, integer=false),
            Ramping("input", :up, 20.0; modifier=mass),
            Ramping("input", :down, 20.0; modifier=mass),
            ReserveUp("test", "input", :up, 1.0; modifier=mass),
        ])
        uc = first(getbehaviors(c, FleetUnitCommitmentBehavior))
        b = first(getbehaviors(c, ReserveBehavior))
        @constraint(sim(c).model, _balance(c, :input, mass, collapse=false)[1] == 3.0)
        @constraint(sim(c).model, _balance(c, :input, mass, collapse=false)[2] == 3.0)
        @constraint(sim(c).model, _state(uc).data[1] == 1)
        @constraint(sim(c).model, _state(uc).data[2] == 1)
        set_objective(sim(c).model, MAX_SENSE, b.r_online.data[2])
        JuMP.set_silent(sim(c).model)
        JuMP.optimize!(sim(c).model)
        @test JuMP.termination_status(sim(c).model) == JuMP.MOI.OPTIMAL
        r_online_val = JuMP.value(b.r_online.data[2])
        @test isapprox(r_online_val, 2.0; atol=1e-5)  # headroom 5-3=2 (1 unit)
    end

    # Unit maxed: upward reserve = 0, downward reserve = flow + r_fast (fast-down when dt >= shutdown). Fix input flow to 10
    let
        c = makecomp([
            FixedCapacity("input", mass, 10.0, unitsize=5.0),
            UnitCommitment("input", 0.5, startup=0, shutdown=0, uptime=0, downtime=0, integer=false),
            Ramping("input", :up, 20.0; modifier=mass),
            Ramping("input", :down, 20.0; modifier=mass),
            ReserveUp("test", "input", :up, 1.0; modifier=mass),
            ReserveDown("test", "input", :down, 1.0; modifier=mass),
        ])
        b_up = upreserve(c)
        b_dn = downreserve(c)
        @constraint(sim(c).model, _balance(c, :input, mass, collapse=false)[1] == 10.0)
        set_objective(sim(c).model, MAX_SENSE, b_up.r.data[1] + b_dn.r.data[1])
        JuMP.set_silent(sim(c).model)
        JuMP.optimize!(sim(c).model)
        @test isapprox(JuMP.value(b_up.r.data[1]), 0.0; atol=1e-6)
        # r_online = flow 10, r_fast = 2 units * 5 * 0.5 (shutdownratio) = 5 => r_dn = 15
        @test isapprox(JuMP.value(b_dn.r.data[1]), 15.0; atol=1e-5)
    end

    # Unit on at partial load: downward reserve = flow + r_fast (fast-down). Fix input flow to 7.5
    let
        c = makecomp([
            FixedCapacity("input", mass, 10.0, unitsize=5.0),
            UnitCommitment("input", 0.5, startup=0, shutdown=0, uptime=0, downtime=0, integer=false),
            Ramping("input", :up, 20.0; modifier=mass),
            Ramping("input", :down, 20.0; modifier=mass),
            ReserveDown("test", "input", :down, 1.0; modifier=mass),
        ])
        b = first(getbehaviors(c, ReserveBehavior))
        @constraint(sim(c).model, _balance(c, :input, mass, collapse=false)[1] == 7.5)
        set_objective(sim(c).model, MAX_SENSE, b.r.data[1])
        JuMP.set_silent(sim(c).model)
        JuMP.optimize!(sim(c).model)
        # r_online = 7.5, r_fast = 2*5*0.5 = 5 => r_dn = 12.5
        @test isapprox(JuMP.value(b.r.data[1]), 12.5; atol=1e-5)
    end

    # Both senses: flow 5 -> headroom 5 (up), downward reserve = flow + r_fast = 5 + 5 = 10
    let
        c = makecomp([
            FixedCapacity("input", mass, 10.0, unitsize=5.0),
            UnitCommitment("input", 0.5, startup=0, shutdown=0, uptime=0, downtime=0, integer=false),
            Ramping("input", :up, 20.0; modifier=mass),
            Ramping("input", :down, 20.0; modifier=mass),
            ReserveUp("test", "input", :up, 1.0; modifier=mass),
            ReserveDown("test", "input", :down, 1.0; modifier=mass),
        ])
        b_up = upreserve(c)
        b_dn = downreserve(c)
        @constraint(sim(c).model, _balance(c, :input, mass, collapse=false)[1] == 5.0)
        set_objective(sim(c).model, MAX_SENSE, b_up.r.data[1] + b_dn.r.data[1])
        JuMP.set_silent(sim(c).model)
        JuMP.optimize!(sim(c).model)
        @test isapprox(JuMP.value(b_up.r.data[1]), 5.0; atol=1e-5)
        @test isapprox(JuMP.value(b_dn.r.data[1]), 10.0; atol=1e-5)  # r_online 5 + r_fast 5
    end

    # Unit off: downward reserve must be 0. Fix input flow = 0 for all t
    let
        c = makecomp([
            FixedCapacity("input", mass, 10.0, unitsize=5.0),
            UnitCommitment("input", 0.5, startup=0, shutdown=0, uptime=0, downtime=0, integer=false),
            Ramping("input", :up, 20.0; modifier=mass),
            Ramping("input", :down, 20.0; modifier=mass),
            ReserveDown("test", "input", :down, 1.0; modifier=mass),
        ])
        b = first(getbehaviors(c, ReserveBehavior))
        @constraint(sim(c).model, _balance(c, :input, mass, collapse=false).data .== 0)
        set_objective(sim(c).model, MAX_SENSE, sum(b.r.data))
        JuMP.set_silent(sim(c).model)
        JuMP.optimize!(sim(c).model)
        r_vals = JuMP.value.(b.r.data)
        @test all(isapprox.(r_vals, 0.0; atol=1e-6))
    end

    # Fast-down: r_fast (down) > 0 when dt >= shutdown and stable_on > 0 (on-units not in shutdown)
    let
        c = makecomp([
            FixedCapacity("input", mass, 10.0, unitsize=5.0),
            UnitCommitment("input", 0.5, startup=0, shutdown=0, uptime=0, downtime=0, integer=false),
            Ramping("input", :down, 20.0; modifier=mass),
            ReserveDown("test", "input", :down, 1.0; modifier=mass),
        ])
        uc = first(getbehaviors(c, FleetUnitCommitmentBehavior))
        b_dn = downreserve(c)
        # Two units on, no shutdown in step 1 => stable_on = 2, r_fast <= 2*5*0.5 = 5
        @constraint(sim(c).model, _state(uc).data[1] == 2)
        @constraint(sim(c).model, _state(uc).data[2] == 2)
        @constraint(sim(c).model, _balance(c, :input, mass, collapse=false)[1] == 5.0)
        set_objective(sim(c).model, MAX_SENSE, sum(b_dn.r_fast.data))
        JuMP.set_silent(sim(c).model)
        JuMP.optimize!(sim(c).model)
        @test JuMP.termination_status(sim(c).model) == JuMP.MOI.OPTIMAL
        rfast = JuMP.value.(b_dn.r_fast.data)
        @test any(rfast .> 1e-6)
        # Per-step cap: (state - shutdown) * unitsize * shutdownratio = 2*5*0.5 = 5
        @test all(rfast .<= 5.0 + 1e-6)
    end

    # Fast-down: dt < shutdown duration → r_fast = 0 (step too short for fast-down)
    let
        c = makecomp([
            FixedCapacity("input", mass, 10.0, unitsize=5.0),
            UnitCommitment("input", 0.5, startup=1, shutdown=1, uptime=0, downtime=0, integer=false),
            Ramping("input", :down, 20.0; modifier=mass),
            ReserveDown("test", "input", :down, 1.0; modifier=mass),
        ])
        uc = first(getbehaviors(c, FleetUnitCommitmentBehavior))
        b_dn = downreserve(c)
        # dt=0.5h < shutdown=1h => r_fast must be 0; state=2, no shutdown in step
        @constraint(sim(c).model, _state(uc).data[1] == 2)
        @constraint(sim(c).model, _state(uc).data[2] == 2)
        @constraint(sim(c).model, _balance(c, :input, mass, collapse=false)[1] == 5.0)
        set_objective(sim(c).model, MAX_SENSE, sum(b_dn.r_fast.data))
        JuMP.set_silent(sim(c).model)
        JuMP.optimize!(sim(c).model)
        @test JuMP.termination_status(sim(c).model) == JuMP.MOI.OPTIMAL
        rfast = JuMP.value.(b_dn.r_fast.data)
        @test all(isapprox.(rfast, 0.0; atol=1e-6))
    end

    # Reserve = 0 during startup phase (only in steps where startup occurs)
    let
        c = makecomp([
            FixedCapacity("input", mass, 10.0, unitsize=5.0),
            UnitCommitment("input", 0.5, startup=1, shutdown=1, uptime=0, downtime=0, integer=false),
            ReserveUp("test", "input", :up, 1.0; modifier=mass),
        ])
        uc = first(getbehaviors(c, FleetUnitCommitmentBehavior))
        b = upreserve(c)
        
        # Force at least one startup: start OFF, end with at least one unit on
        @constraint(sim(c).model, _state(uc).data[1] == 0)
        @constraint(sim(c).model, _state(uc).data[nsteps(sim(c).mesh)] >= 1)
        
        flow = _balance(c, :input, mass, collapse=false)
        set_objective(sim(c).model, MAX_SENSE, sum(flow[i] * (i + 0.1) for i in eachindex(flow)) + sum(b.r.data))
        JuMP.set_silent(sim(c).model)
        JuMP.optimize!(sim(c).model)
        
        @test JuMP.termination_status(sim(c).model) == JuMP.MOI.OPTIMAL
        
        su_vals_vec = [JuMP.value(_su(uc)[i]) for i in 1:nsteps(sim(c).mesh)]
        r_vals_vec = [JuMP.value(b.r.data[i]) for i in 1:nsteps(sim(c).mesh)]
        # At least one startup must occur
        @test any(su_vals_vec .> 1e-6)
        # Reserve must be 0 in every step where startup is active
        @test all((su_vals_vec .<= 1e-6) .| isapprox.(r_vals_vec, 0.0; atol=1e-6))
    end

    # Reserve = 0 during shutdown phase (only in steps where shutdown occurs)
    let
        c = makecomp([
            FixedCapacity("input", mass, 10.0, unitsize=5.0),
            UnitCommitment("input", 0.5, startup=1, shutdown=1, uptime=0, downtime=0, integer=false),
            ReserveUp("test", "input", :up, 1.0; modifier=mass),
        ])
        uc = first(getbehaviors(c, FleetUnitCommitmentBehavior))
        b = upreserve(c)
        
        # Force at least one shutdown: start with 2 units on, end OFF
        @constraint(sim(c).model, _state(uc).data[1] == 2)
        @constraint(sim(c).model, _state(uc).data[nsteps(sim(c).mesh)] == 0)
        
        flow = _balance(c, :input, mass, collapse=false)
        set_objective(sim(c).model, MIN_SENSE, sum(flow[i] * (i + 0.1) for i in eachindex(flow)) - sum(b.r.data))
        JuMP.set_silent(sim(c).model)
        JuMP.optimize!(sim(c).model)
        
        @test JuMP.termination_status(sim(c).model) == JuMP.MOI.OPTIMAL
        
        sd_vals_vec = [JuMP.value(_sd(uc)[i]) for i in 1:nsteps(sim(c).mesh)]
        r_vals_vec = [JuMP.value(b.r.data[i]) for i in 1:nsteps(sim(c).mesh)]
        # At least one shutdown must occur
        @test any(sd_vals_vec .> 1e-6)
        # Reserve must be 0 in every step where shutdown is active
        @test all((sd_vals_vec .<= 1e-6) .| isapprox.(r_vals_vec, 0.0; atol=1e-6))
    end

    # ReserveDown = 0 during shutdown phase (only in steps where shutdown occurs)
    let
        c = makecomp([
            FixedCapacity("input", mass, 10.0, unitsize=5.0),
            UnitCommitment("input", 0.5, startup=1, shutdown=1, uptime=0, downtime=0, integer=false),
            Ramping("input", :down, 20.0; modifier=mass),
            ReserveDown("test", "input", :down, 1.0; modifier=mass),
        ])
        uc = first(getbehaviors(c, FleetUnitCommitmentBehavior))
        b = downreserve(c)
        @constraint(sim(c).model, _state(uc).data[1] == 2)
        @constraint(sim(c).model, _state(uc).data[nsteps(sim(c).mesh)] == 0)
        flow = _balance(c, :input, mass, collapse=false)
        set_objective(sim(c).model, MIN_SENSE, sum(flow[i] * (i + 0.1) for i in eachindex(flow)) - sum(b.r.data))
        JuMP.set_silent(sim(c).model)
        JuMP.optimize!(sim(c).model)
        @test JuMP.termination_status(sim(c).model) == JuMP.MOI.OPTIMAL
        sd_vals_vec = [JuMP.value(_sd(uc)[i]) for i in 1:nsteps(sim(c).mesh)]
        r_vals_vec = [JuMP.value(b.r.data[i]) for i in 1:nsteps(sim(c).mesh)]
        @test any(sd_vals_vec .> 1e-6)
        @test all((sd_vals_vec .<= 1e-6) .| isapprox.(r_vals_vec, 0.0; atol=1e-6))
    end

    # Fast-start: r_fast > 0 when dt >= startup, off_cap > 0 (even with ramping=0)
    let
        s = Sim(Model(HiGHS.Optimizer), mesh=TimeMesh(fill(1//1, 6)))
        mc = MassCarrier("m", s, energy=[1.0, 2.0, 3.0, 4.0, 5.0, 6.0])
        ec = EnergyCarrier("e", s)
        c = Component("gen", BasicConverter(mc, ec), [
            FixedCapacity("input", mass, 10.0, unitsize=5.0),
            UnitCommitment("input", 0.5, startup=0.5, shutdown=0.5, uptime=0, downtime=0, integer=false),
            Ramping("input", :up, 0.0; modifier=mass),
            ReserveUp("test", "input", :up, 1.0; modifier=mass),
        ])
        uc = first(getbehaviors(c, FleetUnitCommitmentBehavior))
        b = first(getbehaviors(c, ReserveBehavior))
        @constraint(sim(c).model, _state(uc).data[1] == 0)
        @constraint(sim(c).model, _state(uc).data[2] == 0)
        set_objective(sim(c).model, MAX_SENSE, sum(b.r_fast.data))
        JuMP.set_silent(sim(c).model)
        JuMP.optimize!(sim(c).model)
        @test JuMP.termination_status(sim(c).model) == JuMP.MOI.OPTIMAL
        rfast = JuMP.value.(b.r_fast.data)
        @test !all(isapprox.(rfast, 0.0; atol=1e-6))
    end

    # UC ramping constraint binds r_online: small ramp limits r_online
    let
        c = makecomp([
            FixedCapacity("input", mass, 10.0, unitsize=5.0),
            UnitCommitment("input", 0.5, startup=0, shutdown=0, uptime=0, downtime=0, integer=false),
            Ramping("input", :up, 4.0; modifier=mass),  # ramp = 4.0 per unit per hour
            ReserveUp("test", "input", :up, 1.0; modifier=mass),
        ])
        uc = first(getbehaviors(c, FleetUnitCommitmentBehavior))
        b = first(getbehaviors(c, ReserveBehavior))
        
        # With 2 units on, _com = 0.5 * 5.0 * 2 = 5.0 per step
        # Fix total flow: step 1 = 6.0, step 2 = 8.0
        # So _var[1] = 1.0, _var[2] = 3.0, var_diff = 2.0 in mass
        # With 2 units on, max_ramp = 2 * 0.5 * 4.0 = 4.0
        # Constraint: var_diff + r_online <= max_ramp => 2.0 + r_online <= 4.0 => r_online <= 2.0
        @constraint(sim(c).model, _balance(c, :input, mass, collapse=false)[1] == 6.0)
        @constraint(sim(c).model, _balance(c, :input, mass, collapse=false)[2] == 8.0)
        @constraint(sim(c).model, _state(uc).data[1] == 2)
        @constraint(sim(c).model, _state(uc).data[2] == 2)

        set_objective(sim(c).model, MAX_SENSE, b.r_online.data[2])
        JuMP.set_silent(sim(c).model)
        JuMP.optimize!(sim(c).model)
        
        @test JuMP.termination_status(sim(c).model) == JuMP.MOI.OPTIMAL
        
        r_online_val = JuMP.value(b.r_online.data[2])
        @test r_online_val <= 2.0 + 1e-6
        @test r_online_val >= 0
        # Headroom from UC: _com + _var = flow; with 2 units, _com = 0.5*5*2 = 5 per step
        com_vals = JuMP.value.(_com(uc).data)
        var_vals = JuMP.value.(_var(uc).data)
        @test isapprox(com_vals[1], 5.0; atol=1e-5)
        @test isapprox(com_vals[2], 5.0; atol=1e-5)
        @test isapprox(var_vals[1], 1.0; atol=1e-5)  # flow[1]=6 => _var[1]=1
        @test isapprox(var_vals[2], 3.0; atol=1e-5)  # flow[2]=8 => _var[2]=3
    end

end

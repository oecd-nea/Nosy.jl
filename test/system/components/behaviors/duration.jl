# Unit tests for Duration behavior 
using Test
using JuMP: Model, MAX_SENSE, set_silent
import JuMP
using Nosy: Duration, buildbehavior, DurationBehavior, _capacitypname, _hours
using Nosy: _balance, balance
using Nosy: PortRef
using Nosy: Sim, TimeMesh, sim
using Nosy: EnergyCarrier, BasicStorage, Component
using Nosy: FixedCapacity, VariableCapacity, CapacityMultiplier
using Nosy: energy
using HiGHS

@testset "Duration" begin

    tsim() = Sim(Model(HiGHS.Optimizer), mesh=TimeMesh(fill(1//1, 10)))

    function makecomp(vbs)
        s = tsim()
        ec = EnergyCarrier("e", s)
        m = BasicStorage(ec)
        return Component("battery", m, vbs)
    end

    let
        d = Duration(6)
        @test d.hours == 6.0
        @test d.inputpname == "input"
        @test d.outputpname == "output"
        @test d.levelpname == "level"
    end
    
    let
        c = makecomp([])
        d = Duration(6, inputpname="nonexistent")
        @test_throws AssertionError buildbehavior(c, d)
    end
    #  Exactly one capacity rule: capacities on both input and output makes fail
    let
        vb = [
            FixedCapacity("input", energy, 100.0),
            FixedCapacity("output", energy, 100.0),
            Duration(6)
        ]
        @test_throws AssertionError makecomp(vb)
    end

    # FixedCapacity with level creates Duration Bahavior)
    let
        vb = [
            FixedCapacity("level", energy, 600.0),
            Duration(6)
        ]
        c = makecomp(vb)
        d = buildbehavior(c, vb[end])
        @test d isa DurationBehavior
        @test _capacitypname(d) == "level"
        @test _hours(d) == 6.0
    end

    # level=600, duration=6 → input/output ≤ 100
    let
        vb = [
            FixedCapacity("level", energy, 600.0),
            Duration(6)
        ]
        c = makecomp(vb)
        JuMP.set_objective(sim(c).model, MAX_SENSE, balance(c, :input, energy, collapse=true))
        set_silent(sim(c).model)
        JuMP.optimize!(sim(c).model)
        result = JuMP.value.(_balance(c, :input, energy, collapse=false))
        @test all(result .<= 100.0)
    end

    # VariableCapacity with ub = 200 kW respected
    let
        vb = [
            VariableCapacity("input", energy, lb=0.0, ub=200.0),
            Duration(6)
        ]
        c = makecomp(vb)
        JuMP.set_objective(sim(c).model, MAX_SENSE, balance(c, :input, energy, collapse=true))
        set_silent(sim(c).model)
        JuMP.optimize!(sim(c).model)
        result = JuMP.value.(_balance(c, :input, energy, collapse=false))
        @test all(result .<= 200.0)
    end

    # Different durations i = 1,2,5,10 -> limit = level / i
    for i in [1, 2, 5, 10]
        let
            cap = 600.0
            vb = [
                FixedCapacity("level", energy, cap),
                Duration(i)
            ]
            c = makecomp(vb)
            JuMP.set_objective(sim(c).model, MAX_SENSE, balance(c, :input, energy, collapse=true))
            set_silent(sim(c).model)
            JuMP.optimize!(sim(c).model)
            result = JuMP.value.(balance(c, :input, energy, collapse=false))
            expected_limit = cap / i
            # @test all(isapprox.(result, expected_limit))
            @test all(result .<= expected_limit)
        end
    end

    # Error (if there isn't capacity)
    let
        vb = [Duration(6)]
        @test_throws AssertionError makecomp(vb)
    end

    # Check it works with capacity multiplier or not
    let
        fc = FixedCapacity("input", energy, 300.0)
        cm = CapacityMultiplier("input", [0.5, 0.8, 1.0, 0.9, 0.6, 0.3, 0.2, 0.4, 0.7, 0.5])
        d = Duration(6)

        c = makecomp([fc, cm, d])
        JuMP.set_objective(sim(c).model, MAX_SENSE, balance(c, :input, energy, collapse=true))
        set_silent(sim(c).model)
        JuMP.optimize!(sim(c).model)

        expected_caps = [v * 300 for v in cm.val]  
        result = JuMP.value.(balance(c, :input, energy, collapse=false))
        @test all(result .<= expected_caps)
    end

    #  Storage level must never exceed input_cap × duration
    let
        vb = [
            FixedCapacity("input", energy, 100.0),
            Duration(6)  # 600
        ]
        c = makecomp(vb)  

        JuMP.set_objective(sim(c).model, MAX_SENSE, balance(c, :input, energy, collapse=true))
        set_silent(sim(c).model)
        JuMP.optimize!(sim(c).model)
        level_vals = JuMP.value.(c.s.level[PortRef("battery", "level")].series)

        @test all(level_vals .<= 600.0)  
    end

    # level = 600, duration = 6 -> optimal flows exactly 100 kW
    let
        vb = [
            FixedCapacity("level", energy, 600.0),
            Duration(6.0)
        ]
        c = makecomp(vb)

        model = sim(c).model
        JuMP.set_objective(model, MAX_SENSE, balance(c, :input, energy, collapse=true))
        set_silent(model)
        JuMP.optimize!(model)

        input_vals = JuMP.value.(balance(c, :input, energy, collapse=false))
        expected_input = [100.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0 ,100.0]

        @test length(input_vals) == length(expected_input)
        @test all(isapprox.(input_vals, expected_input; atol=1e-2))
    end


end

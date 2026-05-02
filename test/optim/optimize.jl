using Nosy: energy
using Nosy: Sim, TimeMesh, Model
using Nosy: DispatchableSource, Demand
using Nosy: EnergyCarrier
using Nosy: VariableCapacity, FixedCost
using Nosy: Component, Node, Snapshot, connect!, optimize!
using Nosy: cost, capacity
using Nosy: filterexpression!, cleanup_bounds!, set_objective!

import JuMP
using JuMP: set_silent, is_solved_and_feasible, objective_value, value
using HiGHS: Optimizer
using Test

@testset "Snapshot optimization" begin

    tsim() = Sim(Model(Optimizer), mesh=TimeMesh(fill(1//2, 10)))

    # objective expression filtering reports removed terms
    let model = Model()
        JuMP.@variable(model, x)
        JuMP.@variable(model, y)
        exp = x + 1e-10 * y

        @test_logs (:warn, "Objective filtering removed 1 terms below relative threshold 1.0e-8. First 1 terms removed: y.") filterexpression!(exp, 1e-8)
        @test JuMP.coefficient(exp, x) ≈ 1.0
        @test JuMP.coefficient(exp, y) == 0.0
    end

    # low upper-bound cleanup reports removed variables
    let s = Sim(Model(); mesh=TimeMesh(fill(1//1, 1)))
        s.options[:boundthreshold] = 1e-3
        snap = Snapshot(s)
        JuMP.@variable(s.model, 0 <= x[1:12] <= 1e-4)
        JuMP.@variable(s.model, 0 <= y <= 1.0)

        @test_logs (:warn, "Optimization cleanup removed 12 variables by fixing them to zero because their upper bound was <= 0.001. First 10 variables fixed: x[1], x[2], x[3], x[4], x[5], x[6], x[7], x[8], x[9], x[10].") cleanup_bounds!(snap)
        @test all(JuMP.is_fixed.(x))
        @test all(JuMP.fix_value.(x) .== 0.0)
        @test !JuMP.is_fixed(y)
    end

    # cleanup and objective filtering use simulation options by default
    let s = Sim(Model(); mesh=TimeMesh(fill(1//1, 1)))
        s.options[:boundthreshold] = 1e-5
        s.options[:objthreshold] = 1e-8
        snap = Snapshot(s)
        JuMP.@variable(s.model, 0 <= z <= 1e-4)
        JuMP.@variable(s.model, a)
        JuMP.@variable(s.model, b)
        exp = a + 1e-10 * b

        cleanup_bounds!(snap)
        @test !JuMP.is_fixed(z)
        @test_logs (:warn, r"Objective filtering removed 1 terms") set_objective!(snap, exp)
        @test JuMP.coefficient(exp, b) == 0.0
    end

    # simple problem that can be solved analytically: deploy same capacity of source as demand
    let s = tsim()
        
        set_silent(s.model) # deactivate JuMP output

        snap = Snapshot(s)

        ec = EnergyCarrier("e", s)
        en = Node("energy", ec)

        disp = Component("disp", DispatchableSource(ec), [VariableCapacity("output", energy), FixedCost(:overnight, "output", energy, 2.)])
        cons = Component("cons", Demand(ec, 10), [])
      
        connect!(snap, cons, en)
        connect!(snap, disp, en)

        optimize!(snap, cost(snap))

        # check that the JuMP model was solved
        @test is_solved_and_feasible(s.model)

        # check the value of the solution
        @test isapprox(objective_value(s.model), 2. * 10.)

        # check the value of the capacity
        @test isapprox(value(capacity(disp)), 10.)


    end


end

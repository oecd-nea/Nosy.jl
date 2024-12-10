using POSY2: energy
using POSY2: Sim, TimeMesh
using POSY2: DispatchableSource, Demand
using POSY2: EnergyCarrier
using POSY2: VariableCapacity, OvernightCost
using POSY2: Component, Node, Snapshot, connect!, optimize!
using POSY2: cost

using JuMP: set_silent, is_solved_and_feasible, objective_value, value
using HiGHS: Optimizer

@testset "Snapshot optimization" begin

    tsim() = Sim(TimeMesh(fill(1//2, 10)), Model(Optimizer))

    # simple problem that can be solved analytically: deploy same capacity of source as demand
    let s = tsim()
        
        set_silent(s.model) # deactivate JuMP output

        snap = Snapshot(s)

        ec = EnergyCarrier("e", s)
        en = Node("energy", ec)

        disp = Component("disp", DispatchableSource(ec), [VariableCapacity("output", energy), OvernightCost(:overnight, "output", energy, 2.)])
        cons = Component("cons", Demand(ec, 10), [])
      
        connect!(snap, cons, en)
        connect!(snap, disp, en)

        optimize!(snap, cost)

        # check that the JuMP model was solved
        @test is_solved_and_feasible(s.model)

        # check the value of the solution
        @test isapprox(objective_value(s.model), 2. * 10.)

        # check the value of the capacity
        @test isapprox(value(capacity(disp)), 10.)


    end


end
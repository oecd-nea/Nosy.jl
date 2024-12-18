using Nosy: energy
using Nosy: Sim, TimeMesh, Model
using Nosy: DispatchableSource, Demand
using Nosy: EnergyCarrier
using Nosy: VariableCapacity, FixedCost
using Nosy: Component, Node, Snapshot, connect!, optimize!
using Nosy: cost, capacity
using Nosy: extract, _extract
using Nosy: dualprice

using JuMP: set_silent, objective_value, value
using HiGHS: Optimizer

@testset "Dual price" begin

    tsim() = Sim(TimeMesh(fill(1//2, 10)), Model(Optimizer))


    # simple problem that can be solved analytically: deploy same capacity of source as demand
    # calculate dual price (simple but not trivial)
    let s = tsim()
        
        set_silent(s.model) # deactivate JuMP output

        snap = Snapshot(s)

        ec = EnergyCarrier("e", s)
        en = Node("energy", ec, evalprice=true)

        # model not optimized
        @test_throws AssertionError dualprice(en)

        disp = Component("disp", DispatchableSource(ec), [VariableCapacity("output", energy), FixedCost(:overnight, "output", energy, 2.), VariableCost(:fuel, "output", energy, 1.)])
        cons = Component("cons", Demand(ec, 10), [])
      
        connect!(snap, cons, en)
        connect!(snap, disp, en)

        optimize!(snap, cost)


        let e = _extract(en)

            @test dualprice(e) isa Stepwise{Float64}
            # first step: overnight cost @ peak demand + variable cost (1/2 hour step)
            # next steps: demand is not peak so only variable cost (1:2 hour step)
            @test all(isapprox.(dualprice(e), [2.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5]))

        end
    end

    # no dual price registered
    let s = tsim()
        
        set_silent(s.model) # deactivate JuMP output

        snap = Snapshot(s)

        ec = EnergyCarrier("e", s)
        en = Node("energy", ec, evalprice=false)

        # model not optimized
        @test_throws AssertionError dualprice(en)

        disp = Component("disp", DispatchableSource(ec), [VariableCapacity("output", energy), FixedCost(:overnight, "output", energy, 2.), VariableCost(:fuel, "output", energy, 1.)])
        cons = Component("cons", Demand(ec, 10), [])
      
        connect!(snap, cons, en)
        connect!(snap, disp, en)

        optimize!(snap, cost)


        let e = _extract(en)

            # no dual price
            @test isnothing(dualprice(e))

        end
    end

end
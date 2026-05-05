using Nosy: energy
using Nosy: Sim, TimeMesh, Model
using Nosy: DispatchableSource, Demand
using Nosy: EnergyCarrier
using Nosy: VariableCapacity, FixedCapacity, FixedCost, VariableCost
using Nosy: UnitCommitment
using Nosy: Component, Node, Snapshot, connect!, optimize!, extract
using Nosy: cost
using Nosy: _extract
using Nosy: dualprice, DualPrice, Hourly
using Nosy: SavedDualPrice

using JuMP: AffExpr, ConstraintRef, has_duals, set_silent
using HiGHS: Optimizer
using ArgCheck: ArgumentError
using Test

@testset "Dual price" begin

    tsim() = Sim(Model(Optimizer), mesh=TimeMesh(fill(1//2, 10)))

    # Empty saved constraint containers mean "no price was defined", not an
    # empty time series.
    @test isnothing(Nosy._dualprice(SavedDualPrice{AffExpr}(ConstraintRef[])).values)


    # simple problem that can be solved analytically: deploy same capacity of source as demand
    # calculate dual price (simple but not trivial)
    let s = tsim()
        
        set_silent(s.model) # deactivate JuMP output

        snap = Snapshot(s)

        ec = EnergyCarrier("e", s)
        en = Node("energy", ec, evalprice=true)
        @test en.dualprice isa SavedDualPrice{AffExpr}

        # model not optimized
        @test_throws ArgumentError dualprice(en)

        disp = Component("disp", DispatchableSource(ec), [VariableCapacity("output", energy), FixedCost(:overnight, "output", energy, 2.), VariableCost(:fuel, "output", energy, 1.)])
        cons = Component("cons", Demand(ec, 10), [])
      
        connect!(snap, cons, en)
        connect!(snap, disp, en)

        optimize!(snap, cost(snap))


        let e = _extract(en)

            @test e.dualprice isa DualPrice{Float64}
            @test fieldnames(typeof(e.dualprice)) == (:values,)
            @test dualprice(e) isa Hourly{Float64}
            # first hour: overnight cost @ peak demand + variable cost
            # next hours: demand is not peak so only variable cost
            @test all(isapprox.(dualprice(e), [2.5, 0.5, 0.5, 0.5, 0.5]))

        end
    end

    # no dual price registered
    let s = tsim()
        
        set_silent(s.model) # deactivate JuMP output

        snap = Snapshot(s)

        ec = EnergyCarrier("e", s)
        en = Node("energy", ec, evalprice=false)

        # model not optimized
        @test_throws ArgumentError dualprice(en)

        disp = Component("disp", DispatchableSource(ec), [VariableCapacity("output", energy), FixedCost(:overnight, "output", energy, 2.), VariableCost(:fuel, "output", energy, 1.)])
        cons = Component("cons", Demand(ec, 10), [])
      
        connect!(snap, cons, en)
        connect!(snap, disp, en)

        optimize!(snap, cost(snap))


        let e = _extract(en)

            # no dual price
            @test isnothing(dualprice(e))

        end
    end

    # duals are unavailable for MIP solutions, even when node constraints are saved
    let s = tsim()

        set_silent(s.model) # deactivate JuMP output

        snap = Snapshot(s)

        ec = EnergyCarrier("e", s)
        en = Node("energy", ec, evalprice=true)

        disp = Component("disp", DispatchableSource(ec), [
            FixedCapacity("output", energy, 10.0, unitsize=10.0),
            UnitCommitment("output", 0.0, integer=true),
            VariableCost(:fuel, "output", energy, 1.0),
        ])
        cons = Component("cons", Demand(ec, 10), [])

        connect!(snap, cons, en)
        connect!(snap, disp, en)

        optimize!(snap, cost(snap))

        @test !has_duals(s.model)

        e = @test_logs (:warn, "Duals are not available - setting price to -Inf") extract(snap)

        @test e isa Snapshot{Float64}
        @test dualprice(e.nodes["energy"]) isa Hourly{Float64}
        @test all(==(-Inf), dualprice(e.nodes["energy"]))

    end

end

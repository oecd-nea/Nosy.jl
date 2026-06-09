import Nosy
using Nosy: energy
using Nosy: Sim, TimeMesh, Model
using Nosy: DispatchableSource, Demand, BasicConverter
using Nosy: EnergyCarrier, MassCarrier
using Nosy: VariableCapacity, FixedCapacity, FixedCost, VariableCost
using Nosy: UnitCommitment
using Nosy: Component, Node, Snapshot, connect!, optimize!, extract
using Nosy: cost, balance, mass
using Nosy: _extract
using Nosy: dualprice, DualPrice, Hourly
using Nosy: SavedDualPrice

using JuMP: AffExpr, ConstraintRef, has_duals, set_silent
using HiGHS: Optimizer
using ArgCheck: ArgumentError
using Test

@testset "Dual price" begin

    tsim() = Sim(Model(Optimizer), mesh=TimeMesh(fill(1//2, 10)))

    function constant_variable_cost_dualprices(weights)
        s = Sim(Model(Optimizer), mesh=TimeMesh(weights))
        set_silent(s.model)

        snap = Snapshot(s)

        ec = EnergyCarrier("e", s)
        en = Node("energy", ec, evalprice=true)
        disp = Component("disp", DispatchableSource(ec), [
            VariableCost(:fuel, "output", energy, 1.0),
        ])
        cons = Component("cons", Demand(ec, 10), [])

        connect!(snap, cons, en)
        connect!(snap, disp, en)

        optimize!(snap, cost(snap))

        return dualprice(en), dualprice(_extract(en))
    end

    # Empty saved constraint containers mean "no price was defined", not an
    # empty time series.
    @test isnothing(Nosy._dualprice(SavedDualPrice{AffExpr}(ConstraintRef[])).values)

    # Node dual prices are reported as hourly energy prices, not raw step-dual
    # values. A flat 1.0 variable cost should therefore return 1.0 on any mesh.
    for weights in (
        fill(1//2, 6),
        fill(1//1, 3),
        fill(2//1, 3),
        [1//2, 1//2, 2//1],
    )
        expected = fill(1.0, Int(sum(weights)))
        live_price, extracted_price = constant_variable_cost_dualprices(weights)
        @test all(isapprox.(live_price, expected; atol=1e-7))
        @test all(isapprox.(extracted_price, expected; atol=1e-7))
    end


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
            # First hour: normalized scarcity price from overnight cost plus
            # variable cost. Next hours carry only variable cost.
            @test all(isapprox.(dualprice(e), [5.0, 1.0, 1.0, 1.0, 1.0]))

        end
    end

    # scaled node constraints still return the economically meaningful price
    let s = Sim(
        Optimizer;
        mesh=TimeMesh(fill(1//2, 10)),
        constraint_scaling=true,
        scalingtarget=1e5,
    )

        set_silent(s.model)

        snap = Snapshot(s)

        ec = EnergyCarrier("e", s)
        en = Node("energy", ec, evalprice=true)

        disp = Component("disp", DispatchableSource(ec), [
            VariableCapacity("output", energy),
            FixedCost(:overnight, "output", energy, 2.0),
            VariableCost(:fuel, "output", energy, 1.0),
        ])
        cons = Component("cons", Demand(ec, 10), [])

        connect!(snap, cons, en)
        connect!(snap, disp, en)

        optimize!(snap, cost(snap))

        # Five half-hour periods at 10 units need 10 units of capacity.
        # Prices are normalized to hourly units, so variable cost is 1.0
        # regardless of timestep duration.
        @test all(isapprox.(dualprice(en), [5.0, 1.0, 1.0, 1.0, 1.0]))
        e = _extract(en)
        @test all(isapprox.(dualprice(e), [5.0, 1.0, 1.0, 1.0, 1.0]))
    end

    # mixed component/node meshes: hourly PEM output is balanced against coarse
    # hydrogen demand at the hydrogen node, and prices are reported per unit.
    let fine = TimeMesh(fill(1//1, 4)), coarse = TimeMesh(fill(2//1, 2))
        s = Sim(Model(Optimizer), mesh=fine)
        set_silent(s.model)

        snap = Snapshot(s)

        power = EnergyCarrier("power", s)
        h2 = MassCarrier("hydrogen", s; energy=1.0)
        grid = Node("grid", power)
        h2node = Node("hydrogen", h2; mesh=coarse, evalprice=true)

        src = Component("src", DispatchableSource(power), [
            VariableCost(:fuel, "output", energy, 1.0),
        ])
        pem = Component("pem", BasicConverter(power, h2; ratio=1.0, modifier=energy, mesh=fine))
        cons = Component("cons", Demand(h2, [10.0, 10.0]; modifier=mass, mesh=coarse))

        connect!(snap, src, grid)
        connect!(snap, pem, grid)
        connect!(snap, pem, h2node)
        connect!(snap, cons, h2node)

        optimize!(snap, cost(snap))
        result = extract(snap)

        @test all(isapprox.(balance(result, "hydrogen", :input, mass, collapse=false, aggregate=true), fill(10.0, 4)))
        @test all(isapprox.(balance(result, "hydrogen", :output, mass, collapse=false, aggregate=true), fill(10.0, 4)))
        @test all(isapprox.(dualprice(result.nodes["hydrogen"]), fill(1.0, 4); atol=1e-7))
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

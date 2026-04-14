using Nosy: energy
using Nosy: Sim, TimeMesh, Model
using Nosy: Stepwise
using Nosy: DispatchableSource, Demand
using Nosy: EnergyCarrier
using Nosy: VariableCapacity, FixedCost
using Nosy: Component, Node, Snapshot, connect!, optimize!
using Nosy: cost, capacity, balance
using Nosy: extract, _extract
import Nosy

using JuMP: set_silent, objective_value, AffExpr, @variable, value
using HiGHS: Optimizer
using Test

@testset "Snapshot extraction" begin

    tsim() = Sim(Model(Optimizer), mesh=TimeMesh(fill(1//2, 10)))

    # test on basic elements
    # _extract should return the element itself, not a copy
    let

        @test _extract("a") === "a"
        
        @test _extract(:a) === :a
        
        @test _extract(1) === 1
        @test _extract(5.) === 5.

        v = [5., 6.]
        @test _extract(v) === v

        r = Base.RefValue(false)
        @test _extract(r) === r

    end

    # tests on simple sim-related elements
    let s = tsim()

        @test _extract(s) === s

        st = Stepwise([6., 7., 8., 9., 10], s.mesh)
        @test _extract(st) === st

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

        # snapshot not optimized yet
        @test_throws AssertionError extract(snap)

        optimize!(snap, cost(snap))

        @assert isapprox(objective_value(s.model), 20.) # check optimization is correct

        @test _extract(ec) == ec

        @test _extract(en) isa Node{Float64, EnergyCarrier}
        
        @assert disp.model isa Nosy.DispatchableSourceModel{EnergyCarrier,AffExpr}
        @test _extract(disp.model) isa Nosy.DispatchableSourceModel{EnergyCarrier,Float64}

        @assert disp.behaviors[1] isa Nosy.VariableCapacityBehavior{AffExpr}
        @test _extract(disp.behaviors[1]) isa Nosy.VariableCapacityBehavior{Float64}

        @assert disp.behaviors[2] isa Nosy.FixedCostBehavior{AffExpr}
        @test _extract(disp.behaviors[2]) isa Nosy.FixedCostBehavior{Float64}

        @assert disp.behaviors isa Vector{Nosy.AbstractRegularBehavior{AffExpr}}
        @test _extract(disp.behaviors) isa Vector{Nosy.AbstractRegularBehavior{Float64}}

        @assert disp.jointflows isa Vector{Nosy.AbstractJointFlow{AffExpr}}
        @test _extract(disp.jointflows) isa Vector{Nosy.AbstractJointFlow{Float64}}

        @test isempty(_extract(disp.jointflows))

        let e = _extract(disp)

            @test e isa Component{Float64}
            @test isempty(e.jointflows)
            @test isapprox(balance(e, :output, energy, collapse=true, aggregate=true), 50.)
            @test isapprox(capacity(e), 10.) 
            @test isapprox(cost(e), 20.)
            

        end

        let e = _extract(cons)

            @test e isa Component{Float64}
            # testing optimal values
            @test isapprox(balance(e, :input, energy, collapse=true, aggregate=true), 50.)
            @test isapprox(capacity(e), 0.) 
            @test isapprox(cost(e), 0.)

        end

        let e = _extract(en)

            @test isapprox(balance(e, :input, energy, collapse=true, aggregate=true), 50.)
            @test isapprox(balance(e, :output, energy, collapse=true, aggregate=true), 50.)

        end

        let e = extract(snap)

            @test isapprox(cost(e), 20.)
            @test isapprox(capacity(e, "disp"), 10.)
            @test isapprox(cost(e, "disp"), 20.)
            @test isapprox(cost(e, "cons"), 0.)

            # already extracted
            @test_throws ArgumentError extract(e)

        end



    end

    # some errors can happen due to collections with abstract types
    # in particular this happens in collections with only one component
    # if no care is given, the collection assumes the concrete component eltype
    # we have to force the abstract type instead

    # snapshot with only one component and one node
    let s = tsim()
        
        set_silent(s.model) # deactivate JuMP output

        snap = Snapshot(s)

        ec = EnergyCarrier("e", s)
        en = Node("energy", ec)

        disp = Component("disp", DispatchableSource(ec), [VariableCapacity("output", energy), FixedCost(:overnight, "output", energy, 2.)])
      
        connect!(snap, disp, en)

        optimize!(snap, cost(snap))

        # test whether the extraction happened
        @test extract(snap) isa Snapshot{Float64}
        @test cost(extract(snap)) == 0.

    end

    # extraction with linked variable capacity
    let s = tsim()

        set_silent(s.model) # deactivate JuMP output

        snap = Snapshot(s)

        ec = EnergyCarrier("e", s)
        en = Node("energy", ec)

        shared_cap = @variable(s.model, base_name="shared_cap")
        disp = Component("disp", DispatchableSource(ec), [VariableCapacity("output", energy; expression=1.0 * shared_cap, lb=0.0, ub=40.0), FixedCost(:overnight, "output", energy, 2.)])
        cons = Component("cons", Demand(ec, 10), [])

        connect!(snap, cons, en)
        connect!(snap, disp, en)

        optimize!(snap, cost(snap))

        # check optimization is correct
        @test isapprox(objective_value(s.model), 20.)
        @test isapprox(value(shared_cap), 10.0)

        # behavior value is extracted
        @test _extract(disp.behaviors[1]) isa Nosy.VariableCapacityBehavior{Float64}

        let 
            @test _extract(disp) isa Component{Float64}
            @test isapprox(capacity(_extract(disp)), 10.0)
            @test isapprox(cost(_extract(disp)), 20.0)
        end

        let 
            @test extract(snap) isa Snapshot{Float64}
            @test isapprox(capacity(extract(snap), "disp"), 10.0)
            @test isapprox(cost(extract(snap), "disp"), 20.0)
        end

    end

end

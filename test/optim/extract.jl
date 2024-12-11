using POSY2: energy
using POSY2: Sim, TimeMesh, Model
using POSY2: DispatchableSource, Demand
using POSY2: EnergyCarrier
using POSY2: VariableCapacity, OvernightCost
using POSY2: Component, Node, Snapshot, connect!, optimize!
using POSY2: cost, capacity, balance
using POSY2: extract, _extract

using JuMP: set_silent, objective_value, value
using HiGHS: Optimizer

@testset "Snapshot extraction" begin

    tsim() = Sim(TimeMesh(fill(1//2, 10)), Model(Optimizer))

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

        disp = Component("disp", DispatchableSource(ec), [VariableCapacity("output", energy), OvernightCost(:overnight, "output", energy, 2.)])
        cons = Component("cons", Demand(ec, 10), [])
      
        connect!(snap, cons, en)
        connect!(snap, disp, en)

        # snapshot not optimized yet
        @test_throws AssertionError extract(snap)

        optimize!(snap, cost)

        @assert isapprox(objective_value(s.model), 20.) # check optimization is correct

        @test _extract(ec) == ec
        
        @assert disp.model isa POSY2.DispatchableSourceModel{EnergyCarrier,AffExpr}
        @test _extract(disp.model) isa POSY2.DispatchableSourceModel{EnergyCarrier,Float64}

        @assert disp.behaviors[1] isa POSY2.VariableCapacityBehavior{AffExpr}
        @test _extract(disp.behaviors[1]) isa POSY2.VariableCapacityBehavior{Float64}

        @assert disp.behaviors[2] isa POSY2.OvernightCostBehavior{AffExpr}
        @test _extract(disp.behaviors[2]) isa POSY2.OvernightCostBehavior{Float64}

        @assert disp.behaviors isa Vector{POSY2.AbstractRegularBehavior{AffExpr}}
        @test _extract(disp.behaviors) isa Vector{POSY2.AbstractRegularBehavior{Float64}}

        @assert disp.jointflows isa Vector{POSY2.AbstractJointFlow{AffExpr}}
        @test _extract(disp.jointflows) isa Vector{POSY2.AbstractJointFlow{Float64}}

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


end
import HiGHS
import JuMP
import MathOptInterface as MOI

using Nosy: ScaledOptimizer

function _finite_nonzero_abs(values)
    return filter(x -> !iszero(x) && isfinite(x), abs.(Float64.(values)))
end

@testset "Constraint scaling" begin
    
    let
    # "MOI layer scales scalar rows"
        inner = MOI.Utilities.Model{Float64}()
        optimizer = ScaledOptimizer(inner; target=1e5)
        x = MOI.add_variable(optimizer)
        y = MOI.add_variable(optimizer)

        f = MOI.ScalarAffineFunction(
            [
                MOI.ScalarAffineTerm(2.0, x),
                MOI.ScalarAffineTerm(-5.0, y),
            ],
            3.0,
        )
        c = MOI.add_constraint(optimizer, f, MOI.LessThan(20.0))

        scaled_f = MOI.get(inner, MOI.ConstraintFunction(), c)
        scaled_set = MOI.get(inner, MOI.ConstraintSet(), c)
        values = _finite_nonzero_abs([
            [term.coefficient for term in scaled_f.terms]
            scaled_f.constant
            scaled_set.upper
        ])
        @test sqrt(minimum(values) * maximum(values)) ≈ 1e5

        @test MOI.get(optimizer, MOI.ConstraintFunction(), c) ≈ f
        @test MOI.get(optimizer, MOI.ConstraintSet(), c).upper ≈ 20.0
    end

    # Left-hand-side constants do not influence the row scale factor
    let
        inner = MOI.Utilities.Model{Float64}()
        optimizer = ScaledOptimizer(inner; target=1e5)
        x = MOI.add_variable(optimizer)

        f = MOI.ScalarAffineFunction([MOI.ScalarAffineTerm(10.0, x)], 1e9)
        c = MOI.add_constraint(optimizer, f, MOI.LessThan(20.0))

        scaled_f = MOI.get(inner, MOI.ConstraintFunction(), c)
        scaled_set = MOI.get(inner, MOI.ConstraintSet(), c)
        values = _finite_nonzero_abs([
            [term.coefficient for term in scaled_f.terms]
            scaled_set.upper
        ])
        @test sqrt(minimum(values) * maximum(values)) ≈ 1e5
    end

    # Tiny coefficients are dropped before the row is scaled
    let
        inner = MOI.Utilities.Model{Float64}()
        optimizer = ScaledOptimizer(inner; target=1e5)
        x = MOI.add_variable(optimizer)
        y = MOI.add_variable(optimizer)

        f = MOI.ScalarAffineFunction(
            [
                MOI.ScalarAffineTerm(1e-9, x),
                MOI.ScalarAffineTerm(10.0, y),
            ],
            0.0,
        )
        c = MOI.add_constraint(optimizer, f, MOI.LessThan(20.0))

        unscaled_f = MOI.get(optimizer, MOI.ConstraintFunction(), c)
        @test length(unscaled_f.terms) == 1
        @test unscaled_f.terms[1].variable == y
        @test unscaled_f.terms[1].coefficient ≈ 10.0

        scaled_f = MOI.get(inner, MOI.ConstraintFunction(), c)
        scaled_set = MOI.get(inner, MOI.ConstraintSet(), c)
        values = _finite_nonzero_abs([
            [term.coefficient for term in scaled_f.terms]
            scaled_set.upper
        ])
        @test sqrt(minimum(values) * maximum(values)) ≈ 1e5
    end

    # Constraint expression threshold is configurable
    let
        inner = MOI.Utilities.Model{Float64}()
        optimizer = ScaledOptimizer(
            inner;
            target=1e5,
            expthreshold=1e-11,
        )
        x = MOI.add_variable(optimizer)
        y = MOI.add_variable(optimizer)

        f = MOI.ScalarAffineFunction(
            [
                MOI.ScalarAffineTerm(1e-9, x),
                MOI.ScalarAffineTerm(10.0, y),
            ],
            0.0,
        )
        c = MOI.add_constraint(optimizer, f, MOI.LessThan(20.0))

        unscaled_f = MOI.get(optimizer, MOI.ConstraintFunction(), c)
        @test length(unscaled_f.terms) == 2
    end

    # Tiny constraint constants and right-hand bounds are dropped before scaling
    let
        inner = MOI.Utilities.Model{Float64}()
        optimizer = ScaledOptimizer(inner; target=1e5, expthreshold=1e-8)
        x = MOI.add_variable(optimizer)

        f = MOI.ScalarAffineFunction([MOI.ScalarAffineTerm(10.0, x)], 1e-9)
        c = MOI.add_constraint(optimizer, f, MOI.LessThan(1e-9))

        unscaled_f = MOI.get(optimizer, MOI.ConstraintFunction(), c)
        unscaled_set = MOI.get(optimizer, MOI.ConstraintSet(), c)
        @test unscaled_f.constant == 0.0
        @test unscaled_set.upper == 0.0

        scaled_f = MOI.get(inner, MOI.ConstraintFunction(), c)
        scaled_set = MOI.get(inner, MOI.ConstraintSet(), c)
        @test scaled_f.constant == 0.0
        @test scaled_set.upper == 0.0
    end

    # Scaling and removed constraint terms are reported once, in total, at optimize time
    let
        model = JuMP.Model(ScaledOptimizer(HiGHS.Optimizer; target=1e5))
        JuMP.set_silent(model)
        JuMP.@variable(model, x >= 0)
        JuMP.@variable(model, y >= 0)
        JuMP.@constraint(model, 1e-9 * x + 10y <= 20)
        JuMP.@constraint(model, 1e-10 * y + x <= 3)
        JuMP.@objective(model, Max, y)

        @test_logs (:warn, r"Constraint scaling scaled 2 scalar affine constraints.*Removed 2 constraint terms") JuMP.optimize!(model)
    end

    # MOI layer scales intervals using both bounds
    let
        inner = MOI.Utilities.Model{Float64}()
        optimizer = ScaledOptimizer(inner; target=1e5)
        x = MOI.add_variable(optimizer)

        f = MOI.ScalarAffineFunction([MOI.ScalarAffineTerm(10.0, x)], 0.0)
        c = MOI.add_constraint(optimizer, f, MOI.Interval(-50.0, 200.0))

        scaled_f = MOI.get(inner, MOI.ConstraintFunction(), c)
        scaled_set = MOI.get(inner, MOI.ConstraintSet(), c)
        values = _finite_nonzero_abs([
            [term.coefficient for term in scaled_f.terms]
            scaled_f.constant
            scaled_set.lower
            scaled_set.upper
        ])
        @test sqrt(minimum(values) * maximum(values)) ≈ 1e5
        @test MOI.get(optimizer, MOI.ConstraintSet(), c).lower ≈ -50.0
        @test MOI.get(optimizer, MOI.ConstraintSet(), c).upper ≈ 200.0
    end

    # JuMP duals stay in original units
    let
        function solve_with(factory)
            model = JuMP.Model(factory)
            JuMP.set_silent(model)
            JuMP.@variable(model, x >= 0)
            con = JuMP.@constraint(model, 2x >= 4)
            JuMP.@objective(model, Min, x)
            JuMP.optimize!(model)
            return JuMP.value(x), JuMP.dual(con), JuMP.objective_value(model)
        end

        reference = solve_with(HiGHS.Optimizer)
        local scaled
        @test_logs (:warn, r"Constraint scaling scaled 1 scalar affine constraints") scaled = solve_with(ScaledOptimizer(HiGHS.Optimizer; target=1e5))
        @test scaled[1] ≈ reference[1]
        @test scaled[2] ≈ reference[2]
        @test scaled[3] ≈ reference[3]
    end

    # Sim optimizer constructor uses scaling by default
    let
        sim = Sim(HiGHS.Optimizer; mesh=TimeMesh(fill(1 // 1, 1)))
        @test occursin("ScaledOptimizer", JuMP.solver_name(sim.model))
        @test sim.options[:boundthreshold] == 1e-3
        @test sim.options[:expthreshold] == 1e-9
        @test sim.options[:scalingtarget] == 1
        @test sim.options[:objthreshold] == 1e-9
    end

    # Sim optimizer constructor keyword arguments override simulation options
    let
        sim = Sim(
            HiGHS.Optimizer;
            mesh=TimeMesh(fill(1 // 1, 1)),
            scalingtarget=1e4,
            expthreshold=1e-11,
        )
        @test sim.options[:scalingtarget] == 1e4
        @test sim.options[:expthreshold] == 1e-11
    end
end

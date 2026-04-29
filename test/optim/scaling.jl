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
        scaled = solve_with(ScaledOptimizer(HiGHS.Optimizer; target=1e5))
        @test scaled[1] ≈ reference[1]
        @test scaled[2] ≈ reference[2]
        @test scaled[3] ≈ reference[3]
    end

    # Sim optimizer constructor uses scaling by default
    let
        sim = Sim(HiGHS.Optimizer; mesh=TimeMesh(fill(1 // 1, 1)))
        @test occursin("ScaledOptimizer", JuMP.solver_name(sim.model))
    end
end
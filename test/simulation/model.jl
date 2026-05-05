using Nosy: Sim, issolvedandfeasible, lowermodel, uppermodel
import JuMP
import MathOptInterface as MOI
using Test

struct UnknownModel <: JuMP.AbstractModel end

@testset "Model" begin

    function mock_bilevel_model(termination_status, primal_status)
        optimizer = MOI.Utilities.MockOptimizer(MOI.Utilities.Model{Float64}())
        MOI.set(optimizer, MOI.TerminationStatus(), termination_status)
        MOI.set(optimizer, MOI.PrimalStatus(), primal_status)
        model = Nosy.BilevelJuMP.BilevelModel()
        model.solver = optimizer
        return model
    end

    let model = Nosy.BilevelJuMP.BilevelModel()
        s = Sim(model)

        @test lowermodel(s) isa Nosy.BilevelJuMP.LowerModel
        @test uppermodel(s) isa Nosy.BilevelJuMP.UpperModel
        @test_throws AssertionError Nosy.model(s)
    end

    @test_throws AssertionError issolvedandfeasible(UnknownModel())
    @test !issolvedandfeasible(JuMP.Model())

    let model = mock_bilevel_model(MOI.OPTIMIZE_NOT_CALLED, MOI.NO_SOLUTION)
        @test !issolvedandfeasible(model)
        @test_throws ArgumentError issolvedandfeasible(model, result=2)
    end

    let model = mock_bilevel_model(MOI.OPTIMAL, MOI.FEASIBLE_POINT)
        @test issolvedandfeasible(model)
        @test issolvedandfeasible(Nosy.BilevelJuMP.Lower(model))
        @test_throws ArgumentError issolvedandfeasible(model, dual=true)
    end

    let model = mock_bilevel_model(MOI.LOCALLY_SOLVED, MOI.FEASIBLE_POINT)
        @test issolvedandfeasible(model)
        @test !issolvedandfeasible(model, allow_local=false)
    end

    let model = mock_bilevel_model(MOI.ALMOST_OPTIMAL, MOI.NEARLY_FEASIBLE_POINT)
        @test !issolvedandfeasible(model)
        @test issolvedandfeasible(model, allow_almost=true)
    end

    let model = mock_bilevel_model(MOI.ALMOST_LOCALLY_SOLVED, MOI.NEARLY_FEASIBLE_POINT)
        @test !issolvedandfeasible(model, allow_almost=true, allow_local=false)
        @test issolvedandfeasible(model, allow_almost=true, allow_local=true)
    end

end

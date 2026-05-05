using Nosy: _to_affexpr
using Nosy: _is_equivalent_to_variable, __containertype, _is_reserved_component_name

using JuMP: @variable, AffExpr, Model, coefficient, constant
using Test

@testset "Data" begin

    @testset "_to_affexpr with JuMP.Model" begin
        model = Model()
        @variable(model, x)
        @variable(model, y[1:2])
        @variable(model, sparse[i=1:3; isodd(i)])

        scalar = _to_affexpr(2, model)
        @test scalar isa AffExpr
        @test constant(scalar) == 2.0

        variable = _to_affexpr(x, model)
        @test variable isa AffExpr
        @test constant(variable) == 0.0
        @test coefficient(variable, x) == 1.0

        expr = 3x + 4
        @test _to_affexpr(expr, model) === expr

        numbers = _to_affexpr([1, 2.5], model)
        @test numbers isa Vector{AffExpr}
        @test constant.(numbers) == [1.0, 2.5]

        variables = _to_affexpr(y, model)
        @test variables[1] isa AffExpr
        @test coefficient(variables[1], y[1]) == 1.0
        @test coefficient(variables[2], y[2]) == 1.0

        sparse_variables = _to_affexpr(sparse, model)
        @test sparse_variables isa Nosy.OrderedDict{Int64,AffExpr}
        @test collect(keys(sparse_variables)) == [1, 3]
        @test coefficient(sparse_variables[1], sparse[1]) == 1.0
        @test coefficient(sparse_variables[3], sparse[3]) == 1.0
    end

    @testset "_to_affexpr with BilevelModel" begin
        model = Nosy.BilevelJuMP.BilevelModel()
        @variable(Nosy.BilevelJuMP.Upper(model), x)

        scalar = _to_affexpr(2, model)
        @test scalar isa Nosy.BilevelJuMP.BilevelAffExpr
        @test constant(scalar) == 2.0

        variable = _to_affexpr(x, model)
        @test variable isa Nosy.BilevelJuMP.BilevelAffExpr
        @test coefficient(variable, x) == 1.0
    end

    @testset "affine expression helpers" begin
        model = Model()
        @variable(model, x)
        @variable(model, y)

        @test _is_equivalent_to_variable(1.0x)
        @test !_is_equivalent_to_variable(2.0x)
        @test !_is_equivalent_to_variable(x + 1.0)
        @test !_is_equivalent_to_variable(x + y)
    end

    @testset "container and reserved-name helpers" begin
        @test __containertype(Dict("a" => 1)) == Dict
        @test __containertype(Nosy.OrderedDict("a" => 1)) == Nosy.OrderedDict

        @test _is_reserved_component_name("losses")
        @test !_is_reserved_component_name("load")
    end

end

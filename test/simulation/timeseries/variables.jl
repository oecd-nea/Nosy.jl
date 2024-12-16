using Nosy: TimeMesh, Stepwise, Sim
using Nosy: nhours, nsteps

using JuMP: Model, @variable, AffExpr, set_lower_bound, set_upper_bound
using JuMP: has_lower_bound, has_upper_bound, lower_bound, upper_bound, is_binary, is_integer


@testset "Stepwise variables" begin

    tsim() = Sim(TimeMesh(fill(1//2, 10)), Model())

    # get variable from a one-variable AffExpr (does not work if AffExpr has multiple terms)
    getvariable(e::AffExpr) = first(e.terms)[1]


    let s = tsim()

        v = Stepwise(s, lb=0., ub=Inf64, binary=false, integer=false, basename="v")

        @test v isa Stepwise{AffExpr}
        @test length(v) == nsteps(s)

        @test all(lower_bound(getvariable(e)) == 0. for e in v)
        @test all(!has_upper_bound(getvariable(e)) for e in v)

        @test all(!is_binary(getvariable(e)) for e in v)
        @test all(!is_integer(getvariable(e)) for e in v)

    end


    let s = tsim()

        v = Stepwise(s, lb=-(1:10), ub=[4,5,6,7,8], binary=false, integer=true, basename="v")

        @test v isa Stepwise{AffExpr}
        @test length(v) == nsteps(s)

        @test all(lower_bound.(getvariable.(v)).data .== collect(-1. * (1:10)))
        @test all(upper_bound.(getvariable.(v)).data .== Stepwise([4,5,6,7,8], s.mesh))

        @test all(!is_binary(getvariable(e)) for e in v)
        @test all(is_integer(getvariable(e)) for e in v)

    end


end
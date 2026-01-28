using Nosy: TimeMesh, Stepwise, Sim
using Nosy: nsteps

using JuMP: Model, GenericAffExpr, lower_bound, upper_bound, has_upper_bound, is_binary, is_integer
using Test


@testset "Stepwise variables" begin

    tsim() = Sim(Model(), mesh=TimeMesh(fill(1//2, 10)))

    # get variable from a one-variable GenericAffExpr (does not work if GenericAffExpr has multiple terms)
    getvariable(e::GenericAffExpr) = first(e.terms)[1]


    let s = tsim()

        v = Stepwise(s, lb=0., ub=Inf64, binary=false, integer=false, basename="v")

        @test v isa Stepwise{<:GenericAffExpr}
        @test length(v) == nsteps(s)

        @test all(lower_bound(getvariable(e)) == 0. for e in v)
        @test all(!has_upper_bound(getvariable(e)) for e in v)

        @test all(!is_binary(getvariable(e)) for e in v)
        @test all(!is_integer(getvariable(e)) for e in v)

    end


    let s = tsim()

        v = Stepwise(s, lb=-(1:10), ub=[4,5,6,7,8], binary=false, integer=true, basename="v")

        @test v isa Stepwise{<:GenericAffExpr}
        @test length(v) == nsteps(s)

        @test all(lower_bound.(getvariable.(v)).data .== collect(-1. * (1:10)))
        @test all(upper_bound.(getvariable.(v)).data .== Stepwise([4,5,6,7,8], s.mesh))

        @test all(!is_binary(getvariable(e)) for e in v)
        @test all(is_integer(getvariable(e)) for e in v)

    end


end

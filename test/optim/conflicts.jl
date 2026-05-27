using Nosy: Sim, Snapshot, conflicts, model

import JuMP
using HiGHS: Optimizer
using Test

@testset "Snapshot conflicts" begin

    let s = Sim(JuMP.Model(Optimizer))
        JuMP.set_silent(model(s))
        snap = Snapshot(s)

        JuMP.@variable(model(s), x)
        JuMP.@constraint(model(s), c1, x >= 1)
        JuMP.@constraint(model(s), c2, x <= 0)
        JuMP.optimize!(model(s))

        sim_conflicts = conflicts(s)
        snapshot_conflicts = conflicts(snap)

        @test snapshot_conflicts == sim_conflicts
        @test length(snapshot_conflicts) == 2
    end

end

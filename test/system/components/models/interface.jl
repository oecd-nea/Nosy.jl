using Nosy: AbstractModelData
using Nosy: Sim, TimeMesh, mesh
using JuMP: Model
using Test

struct MissingMeshModelData <: AbstractModelData
    sim::Sim
end

@testset "Model data interface" begin

    let s = Sim(Model(), mesh=TimeMesh(fill(1//1, 4)))
        err = try
            mesh(MissingMeshModelData(s))
            nothing
        catch e
            e
        end

        @test err isa AssertionError
        @test occursin("No mesh data found for", err.msg)
    end

end

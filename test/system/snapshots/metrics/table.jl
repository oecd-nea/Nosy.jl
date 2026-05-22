using Nosy: Sim, TimeMesh
using Nosy: EnergyCarrier, Node
using Nosy: DispatchableSource
using Nosy: Component, Snapshot, connect!, table
using JuMP: Model
using Test

@testset "Snapshot table" begin
    sim = Sim(Model(), mesh=TimeMesh(fill(1//2, 2)))
    carrier = EnergyCarrier("e", sim)
    snapshot = Snapshot(sim)
    node = Node("node", carrier)

    connect!(snapshot, Component("z", DispatchableSource(carrier)), node)
    connect!(snapshot, Component("a", DispatchableSource(carrier)), node)

    df = table(snapshot, component -> component.name == "a" ? 1 : 2)

    @test names(df) == ["a", "z"]
    @test df[1, "a"] == 1
    @test df[1, "z"] == 2
end

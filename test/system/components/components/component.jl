using POSY2: mass
using POSY2: Sim, TimeMesh
using POSY2: build, buildbehavior
using POSY2: VariableCapacity, VariableCapacityBehavior, _capacity
using POSY2: BasicConverter, BasicConverterModel
using POSY2: MassCarrier, EnergyCarrier
using POSY2: mass, energy
using POSY2: Component, model, sim
using POSY2: behaviors, uniquebehavior, hasbehavior
using JuMP: Model, AffExpr

@testset "Component" begin

    tsim() = Sim(TimeMesh(fill(1//2, 10)), Model())

    getvariable(e::AffExpr) = first(e.terms)[1]

    function makecomp(vbehavior)
        s = tsim()    
        mc = MassCarrier("m", s, energy=[1,2,3,4,5])
        ec = EnergyCarrier("e", s)
        d = BasicConverter(mc, ec)
        c = Component("comp", d, vbehavior)
        return c
    end

    # no behaviors, no joint flows
    let c = makecomp([])

        @test sim(c) == sim(model(c))

        @test model(c) isa BasicConverterModel

        @test isempty(behaviors(c))

        @test isempty(behaviors(c, VariableCapacityBehavior))

        @test isnothing(uniquebehavior(c, VariableCapacityBehavior))

        @test !hasbehavior(c, VariableCapacityBehavior)

    end


    # 1 behavior (variable capacity), no joint flows
    let c = makecomp([VariableCapacity("input", mass, lb=5, ub=Inf64)])

        @test sim(c) == sim(model(c))

        @test model(c) isa BasicConverterModel

        @test !isempty(behaviors(c))

        @test !isempty(behaviors(c, VariableCapacityBehavior))

        @test uniquebehavior(c, VariableCapacityBehavior) isa VariableCapacityBehavior

        @test hasbehavior(c, VariableCapacityBehavior)


    end

end
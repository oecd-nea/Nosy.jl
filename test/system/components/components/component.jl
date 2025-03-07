using Nosy: mass
using Nosy: Sim, TimeMesh
using Nosy: build, buildbehavior
using Nosy: VariableCapacity, VariableCapacityBehavior, _capacity
using Nosy: BasicConverter, BasicConverterModel
using Nosy: MassCarrier, EnergyCarrier
using Nosy: mass, energy
using Nosy: Component, model, sim
using Nosy: behaviors, uniquebehavior, hasbehavior
using JuMP: Model, GenericAffExpr

@testset "Component" begin

    tsim() = Sim(Model(), mesh=TimeMesh(fill(1//2, 10)))

    getvariable(e::GenericAffExpr) = first(e.terms)[1]

    function makecomp(vbehavior, cname::String="comp")
        s = tsim()    
        mc = MassCarrier("m", s, energy=[1,2,3,4,5])
        ec = EnergyCarrier("e", s)
        d = BasicConverter(mc, ec)
        c = Component(cname, d, vbehavior)
        return c
    end

    @test_throws ArgumentError makecomp([], "losses") # "losses" is a reserved name

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
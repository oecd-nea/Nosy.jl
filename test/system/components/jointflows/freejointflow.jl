using Nosy: mass
using Nosy: Sim, TimeMesh, nvariables, nconstraints
using Nosy: FreeJointFlow, FreeJointFlowModel
using Nosy: BasicConverter
using Nosy: MassCarrier, EnergyCarrier
using Nosy: mass, energy
using Nosy: Component
using Nosy: portstructure, input
using JuMP: Model, AffExpr

@testset "FreeJointFlow" begin

    tsim() = Sim(TimeMesh(fill(1//2, 10)), Model())

    getvariable(e::AffExpr) = first(e.terms)[1]

    function makeconvdata()  
        s = tsim()
        mc = MassCarrier("m", s, energy=[1,2,3,4,5])
        ec = EnergyCarrier("e", s)
        d = BasicConverter(
            mc,
            ec,
        )        
        return d
    end


    # input = f(input), mass
    let m = makeconvdata() # model data for converter

        mc = m.input # mass carrier
        ff = FreeJointFlow("ff", mc, :input)

        @test ff isa FreeJointFlow

        c = Component("test", m, [ff])

        @test length(c.jointflows) == 1
        @test first(c.jointflows).data == ff
        @test haskey(input(portstructure(c)), "ff")
        @test !haskey(output(portstructure(c)), "ff")

        @test getport(c, "ff") == input(portstructure(c))["ff"] 

        @test all(iszero(mass(input(portstructure(c))["ff"])[i].constant) for i in eachstep(sim(mc)))
        @test all(length(mass(input(portstructure(c))["ff"])[i].terms) == 1 for i in eachstep(sim(mc)))

        # no variable or constraint should be created here
        @test nvariables(sim(mc)) == 20 # time series for converter model + time series for free joint flow
        @test nconstraints(sim(mc)) == 20 # converter time series lower bounds @ 0 + free joint flow lower bounds

    end


    # error case: try level-type joint flow
    @test_throws ArgumentError FreeJointFlow("ff", MassCarrier("m", tsim()), :level)

    
end
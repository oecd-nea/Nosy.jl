using Nosy: energy
using Nosy: Sim, TimeMesh, nvariables, nconstraints, eachstep, sim
using Nosy: FreeJointFlow
using Nosy: BasicConverter
using Nosy: MassCarrier, EnergyCarrier
using Nosy: Component
using Nosy: portstructure, _input, PortRef
using Nosy: flow, getport, hasinput, hasoutput
using JuMP: Model, GenericAffExpr
using Test

@testset "FreeJointFlow" begin

    tsim() = Sim(Model(), mesh=TimeMesh(fill(1//2, 10)))

    getvariable(e::GenericAffExpr) = first(e.terms)[1]

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
        @test hasinput(c, "ff")
        @test !hasoutput(c, "ff")

        @test getport(c, "ff") == _input(portstructure(c))[PortRef("test", "ff")] 

        @test all(iszero(flow(c, "ff", :input, energy, s).constant) for s in eachstep(sim(mc)))
        @test all(length(flow(c, "ff", :input, energy, s).terms) == 1 for s in eachstep(sim(mc)))

        # no variable or constraint should be created here
        @test nvariables(sim(mc)) == 20 # time series for converter model + time series for free joint flow
        @test nconstraints(sim(mc)) == 20 # converter time series lower bounds @ 0 + free joint flow lower bounds

    end


    # error case: try level-type joint flow
    @test_throws ArgumentError FreeJointFlow("ff", MassCarrier("m", tsim()), :level)

    
end

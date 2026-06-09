using Nosy: mass, energy
using Nosy: Sim, TimeMesh, nvariables, nconstraints
using Nosy: sim, eachstep, Hourly, Stepwise
using Nosy: FixedJointFlow, remesh
using Nosy: BasicConverter
using Nosy: MassCarrier, EnergyCarrier
using Nosy: Component
using Nosy: portstructure, _input, getport, PortRef
using Nosy: hasinput, hasoutput
using Nosy: _balance
using JuMP: Model, GenericAffExpr
using Test

@testset "FixedJointFlow" begin

    tsim() = Sim(Model(), mesh=TimeMesh(fill(1//2, 10)))

    getvariable(e::GenericAffExpr) = first(e.terms)[1]

    function makeconvdata()  
        s = tsim()
        mc = MassCarrier("m", s, energy=[1,2,3,4,5])
        ec = EnergyCarrier("e", s)
        d = BasicConverter(mc,ec)        
        return d
    end


    # vector ~ stepwise series
    let m = makeconvdata() # model data for converter

        mc = m.input # mass carrier
        ff = FixedJointFlow("ff", mc, :input, Float64.(1:10))

        @test ff isa FixedJointFlow

        c = Component("test", m, [ff])

        @test length(c.jointflows) == 1
        @test first(c.jointflows).data == ff
        @test hasinput(c, "ff")
        @test !hasoutput(c, "ff")

        @test getport(c, "ff") == _input(portstructure(c))[PortRef("test", "ff")] 
        
        @test all(_balance(c, :input, mass, collapse=false, aggregate=false)["ff"] .== Float64.(eachstep(sim(mc))))

        # no variable or constraint should be created here
        @test nvariables(sim(mc)) == 10 # time series for converter model
        @test nconstraints(sim(mc)) == 10 # converter time series lower bounds @ 0

    end


    # vector ~ hourly series
    let m = makeconvdata() # model data for converter

        mc = m.input # mass carrier
        ff = FixedJointFlow("ff", mc, :input, Float64.(1:5))

        @test ff isa FixedJointFlow

        c = Component("test", m, [ff])

        @test all(_balance(c, :input, mass, collapse=false, aggregate=false)["ff"][i] == Stepwise(Hourly(Float64.(1:5), sim(c).mesh))[i] for i in eachstep(sim(mc)))

        # no variable or constraint should be created here
        @test nvariables(sim(mc)) == 10 # time series for converter model
        @test nconstraints(sim(mc)) == 10 # converter time series lower bounds @ 0

    end


    # flow series on a finer mesh is remeshed onto a coarser component mesh
    let s = tsim()

        coarse = TimeMesh(fill(1//1, 5))
        mc = MassCarrier("m", s, energy=[1,2,3,4,5])
        ec = EnergyCarrier("e", s)
        d = BasicConverter(mc, ec, mesh=coarse)
        ff = FixedJointFlow("ff", mc, :input, Float64.(1:10))

        c = Component("test", d, [ff])
        expected = remesh(Stepwise(Float64.(1:10), s.mesh), coarse)
        actual = _balance(c, :input, mass, collapse=false, aggregate=false)["ff"]

        @test actual.mesh == coarse
        @test all(actual[i] == expected[i] for i in eachstep(coarse))
        @test sum(actual) == sum(expected)

    end


    # scalar "series"
    let m = makeconvdata() # model data for converter

        mc = m.input # mass carrier
        ff = FixedJointFlow("ff", mc, :input, 5.)

        @test ff isa FixedJointFlow

        c = Component("test", m, [ff])

        @test all(_balance(c, :input, mass, collapse=false, aggregate=false)["ff"][i] == 5. for i in eachstep(sim(mc)))

        # no variable or constraint should be created here
        @test nvariables(sim(mc)) == 10 # time series for converter model
        @test nconstraints(sim(mc)) == 10 # converter time series lower bounds @ 0

    end


    # error case: try level-type joint flow
    @test_throws ArgumentError FixedJointFlow("ff", MassCarrier("m", tsim()), :level, 5.)

    
end

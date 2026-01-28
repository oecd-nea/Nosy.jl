using Nosy: mass, energy
using Nosy: Sim, TimeMesh, nvariables, nconstraints, sim
using Nosy: LinkedJointFlow
using Nosy: BasicConverter
using Nosy: MassCarrier, EnergyCarrier
using Nosy: Component
using Nosy: portstructure, _input, _output, PortRef, hasinput, hasoutput, getport
using Nosy: balance
using JuMP: Model, GenericAffExpr
using Test

@testset "LinkedJointFlow" begin

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
        lf = LinkedJointFlow("lf", mc, :input, "input", x->1.5*x, modifier=mass)

        @test lf isa LinkedJointFlow

        c = Component("test", m, [lf])

        @test length(c.jointflows) == 1
        @test first(c.jointflows).data == lf
        @test hasinput(c, "lf")
        @test !hasoutput(c, "lf")

        @test getport(c, "lf") == _input(portstructure(c))[PortRef("test", "lf")] 

        @test all(balance(c, :input, mass, collapse=false, aggregate=false)["lf"] .== 1.5 * balance(c, :input, mass, collapse=false, aggregate=false)["input"])

        # no variable or constraint should be created here
        @test nvariables(sim(mc)) == 10 # time series for converter model
        @test nconstraints(sim(mc)) == 10 # converter time series lower bounds @ 0.

    end


    # output = f(input), energy
    let m = makeconvdata() # model data for converter

        mc = m.input # mass carrier
        lf = LinkedJointFlow("lf", mc, :output, "input", x->1.5*x, modifier=mass)

        @test lf isa LinkedJointFlow

        c = Component("test", m, [lf])

        @test length(c.jointflows) == 1
        @test first(c.jointflows).data == lf
        @test !hasinput(c, "lf")
        @test hasoutput(c, "lf")

        @test getport(c, "lf") == _output(portstructure(c))[PortRef("test", "lf")] 

        @test all(balance(c, :output, mass, collapse=false, aggregate=false)["lf"] .== 1.5 * balance(c, :input, mass, collapse=false, aggregate=false)["input"])


    end


    # output = f(output), defaultmodifier
    let m = makeconvdata() # model data for converter

        mc = m.input # mass carrier
        lf = LinkedJointFlow("lf", mc, :output, "output", x->1.5*x) # default modifier

        @test lf isa LinkedJointFlow

        c = Component("test", m, [lf])

        @test length(c.jointflows) == 1
        @test first(c.jointflows).data == lf
        @test !hasinput(c, "lf")
        @test hasoutput(c, "lf")

        @test all(balance(c, :output, mass, collapse=false, aggregate=false)["lf"] .== 1.5 * balance(c, :output, energy, collapse=false, aggregate=false)["output"])
    
    end


    # output = f(other joint flow)
    let m = makeconvdata() # model data for converter

        mc = m.input # mass carrier
        lf = LinkedJointFlow("lf", mc, :input, "input", x->1.5*x, modifier=mass)
        lf2 = LinkedJointFlow("lf2", mc, :output, "lf", x->2.0*x, modifier=energy)

        @test lf2 isa LinkedJointFlow

        c = Component("test", m, [lf, lf2])

        @test length(c.jointflows) == 2
        
        # order of joint flows is as defined by user
        @test [c.jointflows[1].data, c.jointflows[2].data] == [lf, lf2]

        @test hasinput(c, "lf")
        @test !hasinput(c, "lf2")
        @test !hasoutput(c, "lf")
        @test hasoutput(c, "lf2")
        
        @test all(balance(c, :input, mass, collapse=false, aggregate=false)["lf"] .== 1.5 * balance(c, :input, mass, collapse=false, aggregate=false)["input"])
        @test all(balance(c, :output, energy, collapse=false, aggregate=false)["lf2"] .== 2.0 * balance(c, :input, energy, collapse=false, aggregate=false)["lf"])

    end


    # error case: try level-type joint flow
    let m = makeconvdata() # model data for converter

        mc = m.input # mass carrier
        @test_throws ArgumentError LinkedJointFlow("lf", mc, :level, "input", x->1.5*x, modifier=mass)

    end

    
end

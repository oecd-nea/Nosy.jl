using Nosy: mass
using Nosy: Sim, TimeMesh, nvariables, nconstraints
using Nosy: LinkedJointFlow, LinkedJointFlowModel
using Nosy: BasicConverter
using Nosy: MassCarrier, EnergyCarrier
using Nosy: mass, energy
using Nosy: Component
using Nosy: portstructure, input
using JuMP: Model, AffExpr

@testset "LinkedJointFlow" begin

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
        lf = LinkedJointFlow("lf", mc, :input, "input", x->1.5*x, modifier=mass)

        @test lf isa LinkedJointFlow

        c = Component("test", m, [lf])

        @test length(c.jointflows) == 1
        @test first(c.jointflows).data == lf
        @test haskey(input(portstructure(c)), "lf")
        @test !haskey(output(portstructure(c)), "lf")

        @test getport(c, "lf") == input(portstructure(c))["lf"] 

        @test all(mass(input(portstructure(c))["lf"]) .== 1.5 * mass(input(portstructure(c))["input"]))

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
        @test !haskey(input(portstructure(c)), "lf")
        @test haskey(output(portstructure(c)), "lf")

        @test getport(c, "lf") == output(portstructure(c))["lf"] 

        @test all(energy(output(portstructure(c))["lf"]) .== 1.5 * energy(input(portstructure(c))["input"]))


    end


    # output = f(output), defaultmodifier
    let m = makeconvdata() # model data for converter

        mc = m.input # mass carrier
        lf = LinkedJointFlow("lf", mc, :output, "output", x->1.5*x) # default modifier

        @test lf isa LinkedJointFlow

        c = Component("test", m, [lf])

        @test length(c.jointflows) == 1
        @test first(c.jointflows).data == lf
        @test !haskey(input(portstructure(c)), "lf")
        @test haskey(output(portstructure(c)), "lf")

        @test getport(c, "lf") == output(portstructure(c))["lf"] 

        @test all(mass(output(portstructure(c))["lf"]) .== 1.5 * energy(output(portstructure(c))["output"]))
    
    end


    # output = f(other joint flow), defaultmodifier
    let m = makeconvdata() # model data for converter

        mc = m.input # mass carrier
        lf = LinkedJointFlow("lf", mc, :input, "input", x->1.5*x, modifier=mass)
        lf2 = LinkedJointFlow("lf2", mc, :output, "lf", x->2.0*x, modifier=energy)

        @test lf2 isa LinkedJointFlow

        c = Component("test", m, [lf, lf2])

        @test length(c.jointflows) == 2
        
        # order of joint flows is as defined by user
        @test [c.jointflows[1].data, c.jointflows[2].data] == [lf, lf2]

        @test haskey(input(portstructure(c)), "lf")
        @test !haskey(input(portstructure(c)), "lf2")
        @test !haskey(output(portstructure(c)), "lf")
        @test haskey(output(portstructure(c)), "lf2")

        @test getport(c, "lf") == input(portstructure(c))["lf"] 
        @test getport(c, "lf2") == output(portstructure(c))["lf2"] 
        
        @test all(mass(input(portstructure(c))["lf"]) .== 1.5 * mass(input(portstructure(c))["input"]))
        @test all(energy(output(portstructure(c))["lf2"]) .== 2.0 * energy(input(portstructure(c))["lf"]))

    end


    # error case: try level-type joint flow
    let m = makeconvdata() # model data for converter

        mc = m.input # mass carrier
        @test_throws ArgumentError LinkedJointFlow("lf", mc, :level, "input", x->1.5*x, modifier=mass)

    end

    
end
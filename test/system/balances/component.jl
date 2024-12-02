using POSY2: MassCarrier, EnergyCarrier, CO2Carrier
using POSY2: mass, energy, co2
using POSY2: Sim, TimeMesh
using POSY2: BasicConverter, LinkedJointFlow
using POSY2: Component
using POSY2: input, output
using POSY2: balance

using JuMP: Model, AffExpr

@testset "Component balance" begin

    
    tsim() = Sim(TimeMesh(fill(1//2, 10)), Model())

    function makecomp1(vbehavior)
        s = tsim()    
        mc = MassCarrier("m", s, energy=[1,2,3,4,5])
        ec = EnergyCarrier("e", s)
        d = BasicConverter(mc, ec)
        c = Component("comp", d, vbehavior)
        return c
    end


    let c = makecomp1([])

        # non-collapsed, non-aggregated balance, mass
        bm = balance(c, :input, mass, collapse=false, aggregate=false)
        @test haskey(bm, "input") && bm["input"] == c.s.input["input"].series
        @test isempty(balance(c, :output, mass, collapse=false, aggregate=false))

        # non-collapsed, non-aggregated balance, energy
        bei = balance(c, :input, energy, collapse=false, aggregate=false)
        @test haskey(bei, "input") && bei["input"] == c.s.input["input"].series .* [1.,1.5,2.,2.5,3.,3.5,4.,4.5,5.,3.]
        beo = balance(c, :output, energy, collapse=false, aggregate=false)
        @test haskey(beo, "output") && beo["output"] == c.s.output["output"].series


        # collapsed, non-aggregated balance, mass
        bm = balance(c, :input, mass, collapse=true, aggregate=false)
        @test haskey(bm, "input") && bm["input"] == sum(c.s.input["input"].series) # NB sum of AffExpr is weighted
        @test isempty(balance(c, :output, mass, collapse=true, aggregate=false))

        # collapsed, non-aggregated balance, energy
        bei = balance(c, :input, energy, collapse=true, aggregate=false)
        @test haskey(bei, "input") && bei["input"] == sum(energy(c.s.input["input"]))
        beo = balance(c, :output, energy, collapse=true, aggregate=false)
        @test haskey(beo, "output") && beo["output"] == sum(c.s.output["output"].series) # NB sum of AffExpr is weighted

    end


    function makecomp2()
        s = tsim()    
        mc = MassCarrier("m", s, energy=[1,2,3,4,5])
        ec = EnergyCarrier("e", s)
        cc = CO2Carrier("co2", s, weight=0.1)
        d = BasicConverter(mc, ec)
        c = Component("comp", d, [LinkedJointFlow("linked", cc, :output, "input", x->x, modifier=mass)])
        return c
    end


    let c = makecomp2()

        # non-collapsed, non-aggregated balance, co2
        @test isempty(balance(c, :input, co2, collapse=false, aggregate=false))
        b = balance(c, :output, co2, collapse=false, aggregate=false)
        @test haskey(b, "linked") && b["linked"] == c.s.output["linked"].series * 0.1

    end


    function makecomp3()
        s = tsim()    
        mc = MassCarrier("m", s, energy=[1,2,3,4,5])
        ec = EnergyCarrier("e", s)
        d = BasicConverter(mc, ec)
        c = Component("comp", d, [LinkedJointFlow("linked", mc, :input, "input", x->3 * x, modifier=mass)])
        return c
    end 
    

    let c = makecomp3()

        # non-collapsed, aggregated balance, mass (with linked joint flow of input mass)
        bm = balance(c, :input, mass, collapse=false, aggregate=true)
        @test bm == c.s.input["input"].series + c.s.input["linked"].series
        @test all(balance(c, :output, mass, collapse=false, aggregate=true) .== zero(AffExpr))
        

        # collapsed, aggregated balance, mass
        bm = balance(c, :input, mass, collapse=true, aggregate=true)
        @test bm == sum(c.s.input["input"].series + c.s.input["linked"].series) # Stepwise sum

        # collapsed, aggregated balance, co2
        @test balance(c, :input, co2, collapse=true, aggregate=true) == zero(AffExpr)

    end


end
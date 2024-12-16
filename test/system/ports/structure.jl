using Nosy: MassCarrier
using Nosy: Stepwise
using Nosy: Sim, TimeMesh
using Nosy: Port
using Nosy: PortStructure, addinput!, addoutput!, addlevel!
using Nosy: hasinput, hasoutput, haslevel, hasport
using Nosy: allports, hasuniquecarrier, isempty
using JuMP: Model, AffExpr

@testset "Port structure" begin

    tsim() = Sim(TimeMesh(fill(1//2, 10)), Model())

    function makeport(s::Sim)
        m = MassCarrier("m", s)
        v = Stepwise([Float64(i) for i in 1:10], s.mesh)
        return Port(m, v)
    end

    #return a port with same carrier but different serie
    copycarrier(p::Port) = Port(p.carrier, similar(p.series), Base.RefValue(false))

    # return true if content of tuples is same (possibly w different order), false otherwise
    containsameelements(t1, t2) = all(e in t2 for e in t1) && all(e in t1 for e in t2)
    

    let s = tsim()

        p1 = makeport(s)
        ps = PortStructure{AffExpr}(s)

        @test isempty(ps)
        @test !hasinput(ps, "p1")
        addinput!(ps, "p1", p1)
        @test !isempty(ps)
        @test hasinput(ps, "p1")
        @test !hasoutput(ps, "p1")
        @test !haslevel(ps, "p1")
        @test allports(ps) == (p1,)

        @test hasport(ps, "p1")
        @test !hasport(ps, "p2")

        @test_throws AssertionError addinput!(ps, "p1", p1)


        p2 = makeport(s)
        addinput!(ps, "p2", p2)
        @test hasinput(ps, "p1")
        @test hasinput(ps, "p2")
        @test containsameelements(allports(ps), (p1, p2))
        

    end


    let s = tsim()

        p1 = makeport(s)
        ps = PortStructure{AffExpr}(s)

        @test !hasoutput(ps, "p1")
        addoutput!(ps, "p1", p1)
        @test hasoutput(ps, "p1")
        @test !isempty(ps)
        @test allports(ps) == (p1,)
        @test_throws AssertionError addoutput!(ps, "p1", p1)

        p2 = makeport(s)
        addoutput!(ps, "p2", p2)
        @test hasoutput(ps, "p1")
        @test hasoutput(ps, "p2")
        @test containsameelements(allports(ps), (p1, p2))
        
    end


    let s = tsim()

        p1 = makeport(s)
        ps = PortStructure{AffExpr}(s)

        @test !haslevel(ps, "p1")
        addlevel!(ps, "p1", p1)
        @test !isempty(ps)
        @test haslevel(ps, "p1")
        @test allports(ps) == (p1,)
        @test_throws AssertionError addlevel!(ps, "p1", p1)

        p2 = makeport(s)
        addlevel!(ps, "p2", p2)
        @test haslevel(ps, "p1")
        @test haslevel(ps, "p2")
        @test containsameelements(allports(ps), (p1, p2))

        @test hasport(ps, "p1")
        @test hasport(ps, "p2")
        @test !hasport(ps, "p3")
        
    end


    let s = tsim()
        
        p1 = makeport(s)
        p2 = copycarrier(p1)
        p3 = copycarrier(p1)
        p4 = copycarrier(p1)

        ps = PortStructure{AffExpr}(s)

        addinput!(ps, "p1", p1)
        @test hasuniquecarrier(ps)

        addinput!(ps, "p2", p2)
        addoutput!(ps, "p3", p3)
        addlevel!(ps, "p4", p4)
        @test hasuniquecarrier(ps)

    end


    let s = tsim()

        p1 = makeport(s)
        p2 = makeport(s)

        ps = PortStructure{AffExpr}(s)

        addinput!(ps, "p1", p1)
        addoutput!(ps, "p2", p2)
        @test !hasuniquecarrier(ps)

    end  


    let s = tsim()

        p1 = makeport(s)
        p2 = makeport(s)

        ps = PortStructure{AffExpr}(s)

        #testing a different combination of senses
        addoutput!(ps, "p1", p1)
        addlevel!(ps, "p2", p2)
        @test !hasuniquecarrier(ps)

    end  

end
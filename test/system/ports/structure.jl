using Nosy: MassCarrier
using Nosy: Stepwise
using Nosy: Sim, TimeMesh
using Nosy: Port, PortRef, PortDict
using Nosy: PortStructure, addinput!, addoutput!, addlevel!, _getport
using Nosy: _hasinput, _hasoutput, _haslevel, hasport
using Nosy: allports, hasuniquecarrier, isempty
using JuMP: Model, AffExpr
using Test

@testset "Port structure" begin

    tsim() = Sim(Model(), mesh=TimeMesh(fill(1//2, 10)))

    function makeport(s::Sim, cname="m")
        m = MassCarrier("m", s)
        v = Stepwise([Float64(i) for i in 1:10], s.mesh)
        return Port(m, v)
    end

    #return a port with same carrier but different serie
    copycarrier(p::Port) = Port(p.carrier, similar(p.series), Base.RefValue(false))

    # return true if content of tuples is same (possibly w different order), false otherwise
    containsameelements(t1, t2) = all(e in t2 for e in t1) && all(e in t1 for e in t2)
    
    
    let s = tsim()
    
        # PortRef
        pra = PortRef("c1", "p1")
        prb = PortRef("c1", "p2")
        prc = PortRef("c2", "p1")
        prd = PortRef("c1", "p1")

        @test pra != prb
        @test pra != prc
        @test pra == prd # different PortRef should be equal if their properties are equal

        # PortDict dict-like behavior
        pa = makeport(s, "ma")
        pb = makeport(s, "mb")

        pd0 = PortDict(Dict{PortRef,Port{AffExpr}}())
        @test isempty(pd0)

        pda = PortDict(Dict(pra => pa))
        pdb = PortDict(Dict(pra => pa, prb => pb))

        @test haskey(pda, pra)
        @test !haskey(pda, prb)

        @test pda[pra] == pa
        @test pdb[pra] == pa && pdb[prb] == pb

        @test length(pda) == 1
        @test length(pdb) == 2

        @test collect(values(pda)) == [pa]
        @test pa ∈ values(pdb) && pb ∈ values(pdb) && length(values(pdb)) == 2

        pdc = copy(pdb)
        @test haskey(pdc, pra) && haskey(pdc, prb)
        @test pdc[pra] == pa && pdc[prb] == pb

        pdc[pra] = pb
        @test pdc[pra] == pb
    end




    let s = tsim()

        p1 = makeport(s)
        ps = PortStructure{AffExpr}(s)

        @test isempty(ps)
        @test !_hasinput(ps, "p1", "c1")
        addinput!(ps, "p1", "c1", p1)
        @test !isempty(ps)
        @test _hasinput(ps, "p1", "c1")
        @test !_hasoutput(ps, "p1", "c1")
        @test !_haslevel(ps, "p1", "c1")
        @test allports(ps) == (p1,)
        @test _getport(ps, "p1", "c1") == p1

        @test hasport(ps, "p1", "c1")
        @test !hasport(ps, "p2", "c1")

        # cannot add a second time the same port from the same component
        @test_throws AssertionError addinput!(ps, "p1", "c1", p1)
        @test_throws AssertionError addoutput!(ps, "p1", "c1", p1)
        @test_throws AssertionError addlevel!(ps, "p1", "c1", p1)

        p2 = makeport(s)
        addinput!(ps, "p2", "c1", p2)
        @test _hasinput(ps, "p1", "c1")
        @test _hasinput(ps, "p2", "c1")

    end


    let s = tsim()

        p1 = makeport(s)
        ps = PortStructure{AffExpr}(s)

        @test !_hasoutput(ps, "p1", "c1")
        addoutput!(ps, "p1", "c1", p1)
        @test _hasoutput(ps, "p1", "c1")
        @test !isempty(ps)
        @test allports(ps) == (p1,)
        @test _getport(ps, "p1", "c1") == p1

        # cannot add a second time the same port from the same component
        @test_throws AssertionError addinput!(ps, "p1", "c1", p1)
        @test_throws AssertionError addoutput!(ps, "p1", "c1", p1)
        @test_throws AssertionError addlevel!(ps, "p1", "c1", p1)

        p2 = makeport(s)
        addoutput!(ps, "p2", "c2", p2)
        @test _hasoutput(ps, "p1", "c1")
        @test _hasoutput(ps, "p2", "c2")
        @test all(ps.output[PortRef("c2", "p2")].series .== p2.series)

        
        
    end


    let s = tsim()

        p1 = makeport(s)
        ps = PortStructure{AffExpr}(s)

        @test !_haslevel(ps, "p1", "c1")
        addlevel!(ps, "p1", "c1", p1)
        @test !isempty(ps)
        @test _haslevel(ps, "p1", "c1")
        @test allports(ps) == (p1,)

        # cannot add a second time the same port from the same component
        @test_throws AssertionError addinput!(ps, "p1", "c1", p1)
        @test_throws AssertionError addoutput!(ps, "p1", "c1", p1)
        @test_throws AssertionError addlevel!(ps, "p1", "c1", p1)
        
        p2 = makeport(s)
        addlevel!(ps, "p2", "c2", p2)
        @test _haslevel(ps, "p1", "c1")
        @test _haslevel(ps, "p2", "c2")
        @test containsameelements(allports(ps), (p1, p2))

        @test hasport(ps, "p1", "c1")
        @test hasport(ps, "p2", "c2")
        @test !hasport(ps, "p3", "c3")
        
    end


    let s = tsim()
        
        p1 = makeport(s)
        p2 = copycarrier(p1)
        p3 = copycarrier(p1)
        p4 = copycarrier(p1)

        ps = PortStructure{AffExpr}(s)

        addinput!(ps, "p1", "c1", p1)
        @test hasuniquecarrier(ps)

        addinput!(ps, "p2", "c2", p2)
        addoutput!(ps, "p3", "c3", p3)
        addlevel!(ps, "p4", "c4", p4)
        @test hasuniquecarrier(ps)

    end


    let s = tsim()

        p1 = makeport(s)
        p2 = makeport(s)

        ps = PortStructure{AffExpr}(s)

        addinput!(ps, "p1", "c1", p1)
        addoutput!(ps, "p2", "c2", p2)
        @test !hasuniquecarrier(ps)

    end  


    let s = tsim()

        p1 = makeport(s)
        p2 = makeport(s)

        ps = PortStructure{AffExpr}(s)

        #testing a different combination of senses
        addoutput!(ps, "p1", "c1", p1)
        addlevel!(ps, "p2", "c2", p2)
        @test !hasuniquecarrier(ps)

    end

end
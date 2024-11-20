using POSY2: MassCarrier, EnergyCarrier, CO2Carrier
using POSY2: mass, energy, co2
using POSY2: Stepwise
using POSY2: Sim, TimeMesh
using POSY2: Port
using POSY2: PortStructure, addinput!, addoutput!, addlevel!
using POSY2: input, output, level
using POSY2: _balance

using JuMP: Model, AffExpr

@testset "Port structure balance" begin

    
    tsim() = Sim(TimeMesh(fill(1//2, 10_000)), Model())

    function makeport_m(s::Sim)
        m = MassCarrier("m", s)
        v = Stepwise([Float64(i) for i in 1:10_000], s.mesh)
        return Port(m, v)
    end

    # NB this energy port also bears mass due to "energy" keyword
    function makeport_e(s::Sim)
        m = EnergyCarrier("e", s, energy=2.)
        v = Stepwise([Float64(i) for i in 1:10_000], s.mesh)
        return Port(m, v)
    end

    function makeport_c(s::Sim)
        m = CO2Carrier("e", s, weight=0.5)
        v = Stepwise([Float64(i) for i in 1:10_000], s.mesh)
        return Port(m, v)
    end

    let s = tsim()

        # tests on input of port structure only
        p1 = makeport_m(s)
        p2 = makeport_m(s)
        ps = PortStructure{AffExpr}(s)
        addinput!(ps, "p1", p1)
        addinput!(ps, "p2", p2)

        # non-collapsed, non-aggregated balance
        b = _balance(ps, input, mass, false, false)
        @test haskey(b, "p1") && b["p1"] == mass(p1)
        @test haskey(b, "p2") && b["p2"] == mass(p2)       
        @test isempty(_balance(ps, output, mass, false, false))
        @test isempty(_balance(ps, level, mass, false, false))

        @test isempty(_balance(ps, input, energy, false, false))
        @test isempty(_balance(ps, output, energy, false, false))
        @test isempty(_balance(ps, level, energy, false, false))

        # collapsed, non-aggregated balance
        b = _balance(ps, input, mass, true, false)
        @test haskey(b, "p1") && b["p1"] == sum(mass(p1))
        @test haskey(b, "p2") && b["p2"] == sum(mass(p2))
        @test isempty(_balance(ps, output, mass, true, false))
        @test isempty(_balance(ps, level, mass, true, false))

        @test isempty(_balance(ps, input, energy, true, false))
        @test isempty(_balance(ps, output, energy, true, false))
        @test isempty(_balance(ps, level, energy, true, false))

        # non-collapsed, aggregated balance
        @test _balance(ps, input, mass, false, true) == mass(p1) + mass(p2)
        @test iszero(_balance(ps, output, mass, false, true))
        @test iszero(_balance(ps, level, mass, false, true))

        @test iszero(_balance(ps, input, energy, false, true))
        @test iszero(_balance(ps, output, energy, false, true))
        @test iszero(_balance(ps, level, energy, false, true))

        # collapsed, aggregated balance
        @test _balance(ps, input, mass, true, true) == sum(mass(p1)) + sum(mass(p2))
        @test iszero(_balance(ps, output, mass, true, true))
        @test iszero(_balance(ps, level, mass, true, true))

        @test iszero(_balance(ps, input, energy, true, true))
        @test iszero(_balance(ps, output, energy, true, true))
        @test iszero(_balance(ps, level, energy, true, true))

    end


    let s = tsim()

        # tests of expanded balance only on a more complex port structure
        p1 = makeport_m(s)
        p2 = makeport_m(s)
        p3 = makeport_e(s)
        p4 = makeport_e(s)
        p5 = makeport_c(s)


        ps = PortStructure{AffExpr}(s)
        addinput!(ps, "p1", p1) # 2 mass inputs
        addinput!(ps, "p2", p2)
        addinput!(ps, "p3", p3) # 1 energy input, 1 energy output
        addoutput!(ps, "p4", p4)
        addoutput!(ps, "p5", p5) # 1 co2 output

        # non-collapsed, non-aggregated balance
        let b = _balance(ps, input, mass, false, false)
            @test haskey(b, "p1") && b["p1"] == mass(p1)
            @test haskey(b, "p2") && b["p2"] == mass(p2)
            @test haskey(b, "p3") && b["p3"] == mass(p3)
            @test !haskey(b, "p4") # output & no mass
            @test !haskey(b, "p5") # output
        end

        let b = _balance(ps, output, mass, false, false)
            @test !haskey(b, "p1") # input
            @test !haskey(b, "p2") # input
            @test !haskey(b, "p3") # input & no mass
            @test haskey(b, "p4") && b["p4"] == mass(p4)
            @test haskey(b, "p5") && b["p5"] == mass(p5)
        end
        
        let b = _balance(ps, input, energy, false, false)
            @test !haskey(b, "p1") # no energy
            @test !haskey(b, "p2") # no energy
            @test haskey(b, "p3") && b["p3"] == energy(p3)
            @test !haskey(b, "p4") # output
            @test !haskey(b, "p5") # no energy
        end

        let b = _balance(ps, output, co2, false, false)
            @test !haskey(b, "p1") # input & no co2
            @test !haskey(b, "p2") # input & no co2
            @test !haskey(b, "p3") # input & no co2
            @test !haskey(b, "p4") # no co2
            @test haskey(b, "p5") && b["p5"] == co2(p5)
        end

    end


end


using Nosy: MassCarrier, EnergyCarrier, CO2Carrier
using Nosy: mass, energy, co2
using Nosy: Stepwise
using Nosy: Sim, TimeMesh
using Nosy: Port, PortRef
using Nosy: PortStructure, addinput!, addoutput!, addlevel!
using Nosy: _input, _output, _level
using Nosy: _balance

using JuMP: Model, AffExpr

@testset "Port structure balance" begin

    
    tsim() = Sim(Model(), mesh=TimeMesh(fill(1//2, 10)))

    function makeport_m(s::Sim)
        m = MassCarrier("m", s)
        v = Stepwise([Float64(i) for i in 1:10], s.mesh)
        return Port(m, v)
    end

    # NB this energy port also bears mass due to "energy" keyword
    function makeport_e(s::Sim)
        m = EnergyCarrier("e", s, energy=2.)
        v = Stepwise([Float64(i) for i in 1:10], s.mesh)
        return Port(m, v)
    end

    function makeport_c(s::Sim)
        m = CO2Carrier("e", s, weight=0.5)
        v = Stepwise([Float64(i) for i in 1:10], s.mesh)
        return Port(m, v)
    end

    let s = tsim()

        # tests on input of port structure only
        p1 = makeport_m(s)
        p2 = makeport_m(s)
        ps = PortStructure{AffExpr}(s)
        addinput!(ps, "p1", "c", p1)
        addinput!(ps, "p2", "c", p2)

        # non-collapsed, non-aggregated balance
        b = _balance(ps, _input, mass, false, false)
        @test haskey(b, PortRef("c", "p1")) && b[PortRef("c", "p1")] == mass(p1)
        @test haskey(b, PortRef("c", "p2")) && b[PortRef("c", "p2")] == mass(p2)       
        @test isempty(_balance(ps, _output, mass, false, false))
        @test isempty(_balance(ps, _level, mass, false, false))

        @test isempty(_balance(ps, _input, energy, false, false))
        @test isempty(_balance(ps, _output, energy, false, false))
        @test isempty(_balance(ps, _level, energy, false, false))

        # collapsed, non-aggregated balance
        b = _balance(ps, _input, mass, true, false)
        @test haskey(b, PortRef("c", "p1")) && b[PortRef("c", "p1")] == sum(mass(p1))
        @test haskey(b, PortRef("c", "p2")) && b[PortRef("c", "p2")] == sum(mass(p2))
        @test isempty(_balance(ps, _output, mass, true, false))
        @test isempty(_balance(ps, _level, mass, true, false))

        @test isempty(_balance(ps, _input, energy, true, false))
        @test isempty(_balance(ps, _output, energy, true, false))
        @test isempty(_balance(ps, _level, energy, true, false))

        # non-collapsed, aggregated balance
        @test _balance(ps, _input, mass, false, true) == mass(p1) + mass(p2)
        @test iszero(_balance(ps, _output, mass, false, true))
        @test iszero(_balance(ps, _level, mass, false, true))

        @test iszero(_balance(ps, _input, energy, false, true))
        @test iszero(_balance(ps, _output, energy, false, true))
        @test iszero(_balance(ps, _level, energy, false, true))

        # collapsed, aggregated balance
        @test _balance(ps, _input, mass, true, true) == sum(mass(p1)) + sum(mass(p2))
        @test iszero(_balance(ps, _output, mass, true, true))
        @test iszero(_balance(ps, _level, mass, true, true))

        @test iszero(_balance(ps, _input, energy, true, true))
        @test iszero(_balance(ps, _output, energy, true, true))
        @test iszero(_balance(ps, _level, energy, true, true))

    end


    let s = tsim()

        # tests of expanded balance only on a more complex port structure
        p1 = makeport_m(s)
        p2 = makeport_m(s)
        p3 = makeport_e(s)
        p4 = makeport_e(s)
        p5 = makeport_c(s)


        ps = PortStructure{AffExpr}(s)
        addinput!(ps, "p1", "c", p1) # 2 mass inputs
        addinput!(ps, "p2", "c", p2)
        addinput!(ps, "p3", "c", p3) # 1 energy input, 1 energy output
        addoutput!(ps, "p4", "c", p4)
        addoutput!(ps, "p5", "c", p5) # 1 co2 output

        # non-collapsed, non-aggregated balance
        let b = _balance(ps, _input, mass, false, false)
            @test haskey(b, PortRef("c", "p1")) && b[PortRef("c", "p1")] == mass(p1)
            @test haskey(b, PortRef("c", "p2")) && b[PortRef("c", "p2")] == mass(p2)
            @test haskey(b, PortRef("c", "p3")) && b[PortRef("c", "p3")] == mass(p3)
            @test !haskey(b, PortRef("c", "p4")) # output & no mass
            @test !haskey(b, PortRef("c", "p5")) # output
        end

        let b = _balance(ps, _output, mass, false, false)
            @test !haskey(b, PortRef("c", "p1")) # input
            @test !haskey(b, PortRef("c", "p2")) # input
            @test !haskey(b, PortRef("c", "p3")) # input & no mass
            @test haskey(b, PortRef("c", "p4")) && b[PortRef("c", "p4")] == mass(p4)
            @test haskey(b, PortRef("c", "p5")) && b[PortRef("c", "p5")] == mass(p5)
        end
        
        let b = _balance(ps, _input, energy, false, false)
            @test !haskey(b, PortRef("c", "p1")) # no energy
            @test !haskey(b, PortRef("c", "p2")) # no energy
            @test haskey(b, PortRef("c", "p3")) && b[PortRef("c", "p3")] == energy(p3)
            @test !haskey(b, PortRef("c", "p4")) # output
            @test !haskey(b, PortRef("c", "p5")) # no energy
        end

        let b = _balance(ps, _output, co2, false, false)
            @test !haskey(b, PortRef("c", "p1")) # input & no co2
            @test !haskey(b, PortRef("c", "p2")) # input & no co2
            @test !haskey(b, PortRef("c", "p3")) # input & no co2
            @test !haskey(b, PortRef("c", "p4")) # no co2
            @test haskey(b, PortRef("c", "p5")) && b[PortRef("c", "p5")] == co2(p5)
        end

    end


end


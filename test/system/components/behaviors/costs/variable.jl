using POSY2: mass, energy
using POSY2: Sim, TimeMesh
using POSY2: build
using POSY2: BasicConverter
using POSY2: LinkedJointFlow
using POSY2: VariableCost, VariableCostBehavior
using POSY2: variablecost, _variablecost
using POSY2: MassCarrier, EnergyCarrier
using POSY2: mass, energy
using POSY2: Component, balance
using JuMP: Model, AffExpr
using ArgCheck: ArgumentError

@testset "VariableCost" begin

    tsim() = Sim(TimeMesh(fill(1//2, 10)), Model())

    function makeconv(vb)
        s = tsim()    
        mc = MassCarrier("m", s, energy=[1,2,3,4,5])
        ec = EnergyCarrier("e", s)
        d = BasicConverter(
            mc,
            ec,
        )   
        c = Component("comp", d, vb)
        return c
    end

    # scalar variable cost
    let c = makeconv([VariableCost("input", mass, 10)])

        @test c.behaviors[1] isa VariableCostBehavior{AffExpr}

        # adapting to fixed capacity
        @test _variablecost(c.behaviors[1]) == 10 * balance(c, :input, mass, collapse=true, aggregate=true)

        # component metric
        @test variablecost(c) == _variablecost(c.behaviors[1])

    end

    # vectorial variable cost - stepwise format
    let c = makeconv([VariableCost("input", mass, fill(10,10))])

        # adapting to variable capacity
        @test isapprox(_variablecost(c.behaviors[1]), 10 * balance(c, :input, mass, collapse=true, aggregate=true))

        # component metric
        @test variablecost(c) == _variablecost(c.behaviors[1])

    end


    # vectorial variable cost - hourly format
    let c = makeconv([VariableCost("input", mass, fill(10,5))])

        # adapting to variable capacity
        @test isapprox(_variablecost(c.behaviors[1]), 10 * balance(c, :input, mass, collapse=true, aggregate=true))


        # component metric
        @test isapprox(variablecost(c), 10 * balance(c, :input, mass, collapse=true, aggregate=true))


    end


    # vectorial variable cost - wrong format
    @test_throws AssertionError makeconv([VariableCost("input", mass, fill(10,7))])


    # multiple variable costs
    let c = makeconv([VariableCost("input", mass, 1), VariableCost("input", energy, 1)])

        @test variablecost(c) == _variablecost(c.behaviors[1]) + _variablecost(c.behaviors[2])

    end

    # no variable costs
    let c = makeconv([])

        @test variablecost(c) == 0. # Float64 (reduce memory allocation)

    end

end
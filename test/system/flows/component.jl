using Nosy: MassCarrier, EnergyCarrier, CO2Carrier
using Nosy: mass, energy, co2
using Nosy: Sim, TimeMesh
using Nosy: BasicConverter, LinkedJointFlow
using Nosy: Component
using Nosy: _flow, flow
using Nosy: _extract

using JuMP: Model, AffExpr, @constraint, set_objective, set_silent
import JuMP: MAX_SENSE

using HiGHS

@testset "Component flow" begin

    
    tsim() = Sim(TimeMesh(fill(1//2, 10)), Model(HiGHS.Optimizer))

    function makecomp1(vbehavior)
        s = tsim()    
        mc = MassCarrier("m", s, energy=1:10)
        ec = EnergyCarrier("e", s)
        d = BasicConverter(mc, ec, ratio=0.5)
        c = Component("comp", d, vbehavior)
        @constraint(s.model, c.s.input["input"].series.data .== collect(1:10))
        set_objective(s.model, MAX_SENSE, balance(c, :input, mass))
        set_silent(s.model)
        JuMP.optimize!(s.model)
        return _extract(c)
    end


    let c = makecomp1([])

        # flow at a given step

        @test all((_flow(c, "input", mass, step) for step in 1:10) .== 1:10)
        @test all((_flow(c, "input", energy, step) for step in 1:10) .== ((1:10) .* (1:10)))        
        @test all((_flow(c, "output", energy, step) for step in 1:10) .== ((1:10) * 0.5))
        
        @test_throws AssertionError _flow(c, "p1", co2, 1) # CO2 modifier not compatible
        @test_throws AssertionError _flow(c, "noname", mass, 1) # no port named "noname"

        @test all((_flow(c, :input, mass, step) for step in 1:10) .== (1:10))
        @test all((_flow(c, :output, energy, step) for step in 1:10) .== ((1:10) * 0.5))

        @test all((_flow(c, :input, energy, step) for step in 1:10) .== ((1:10) .* (1:10)))

        @test all(iszero(_flow(c, :output, co2, step)) for step in 1:10)

        

        # flow at a given hour

        @test all((flow(c, "input", mass, h) for h in 1:5) .== 1:2:10)
        @test all((flow(c, "input", energy, h) for h in 1:5) .== ((1:2:10) .* (1:2:10)))
        @test all((flow(c, "output", energy, h) for h in 1:5) .== ((1:2:10) * 0.5))
        
        @test_throws AssertionError flow(c, "p1", co2, 1) # CO2 modifier not compatible
        @test_throws AssertionError flow(c, "noname", mass, 1) # no port named "noname"

        @test all((flow(c, :input, mass, h) for h in 1:5) .== (1:2:10))
        @test all((flow(c, :output, energy, h) for h in 1:5) .== ((1:2:10) * 0.5))

        @test all((flow(c, :input, energy, h) for h in 1:5) .== ((1:2:10) .* (1:2:10)))

        @test all(iszero(_flow(c, :output, co2, h)) for h in 1:5)

    end

end
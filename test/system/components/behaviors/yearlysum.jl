using Nosy: mass, energy
using Nosy: Sim, TimeMesh, sim
using Nosy: FixedCapacity
using Nosy: YearlySum
using Nosy: BasicConverter
using Nosy: MassCarrier, EnergyCarrier
using Nosy: Component
using Nosy: balance, _extract
using JuMP: Model, set_objective, MIN_SENSE, MAX_SENSE
import JuMP
using ArgCheck: ArgumentError
import HiGHS
using Test

@testset "YearlySum" begin

    tsim() = Sim(Model(HiGHS.Optimizer), mesh=TimeMesh(fill(1//2, 10)))

    function makecomp(vbehavior=[])
        s = tsim()    
        mc = MassCarrier("m", s, energy=[1,2,3,4,5])
        ec = EnergyCarrier("e", s)
        d = BasicConverter(mc, ec)
        c = Component("comp", d, vbehavior)
        return c
    end

    # value must be positive or zero
    @test_throws ArgumentError YearlySum("output", -20., :equal)

    # type must be in (:equal, :max, :min)
    @test_throws ArgumentError YearlySum("output", 20., :other)


    let 

        c = makecomp([FixedCapacity("input", mass, 5.), YearlySum("input", 20., :equal)]) # defaultmodifier -> mass
        
        set_objective(sim(c).model, MAX_SENSE, balance(c, :output, energy))
        JuMP.set_silent(sim(c).model)
        JuMP.optimize!(sim(c).model)
        _c = _extract(c)

        @test isapprox(balance(_c, :input, mass), 20.)

    end

    let

        s = Sim(Model(HiGHS.Optimizer), mesh=TimeMesh(fill(2//1, 2)))
        mc = MassCarrier("m", s, energy=[1,2,3,4])
        ec = EnergyCarrier("e", s)
        c = Component("comp", BasicConverter(mc, ec), [
            FixedCapacity("input", mass, 5.),
            YearlySum("input", 20., :equal),
        ])

        set_objective(sim(c).model, MAX_SENSE, balance(c, :output, energy))
        JuMP.set_silent(sim(c).model)
        JuMP.optimize!(sim(c).model)
        _c = _extract(c)

        @test isapprox(balance(_c, :input, mass), 20.; atol=1e-6)
        @test all(isapprox.(balance(_c, :input, mass, collapse=false).data, [5., 5., 5., 5.]; atol=1e-6))

    end

    let 

        c = makecomp([FixedCapacity("input", mass, 5.), YearlySum("input", 20., :equal, modifier=energy)]) # defaultmodifier -> mass
        
        set_objective(sim(c).model, MAX_SENSE, balance(c, :output, energy))
        JuMP.set_silent(sim(c).model)
        JuMP.optimize!(sim(c).model)
        _c = _extract(c)

        @test isapprox(balance(_c, :input, energy), 20.)

    end

    let 

        c = makecomp([FixedCapacity("input", mass, 5.), YearlySum("input", 20., :min)])
        
        set_objective(sim(c).model, MAX_SENSE, balance(c, :output, energy))
        JuMP.set_silent(sim(c).model)
        JuMP.optimize!(sim(c).model)
        _c = _extract(c)

        @test isapprox(balance(_c, :input, mass), 25.)

    end

    let 

        c = makecomp([FixedCapacity("input", mass, 5.), YearlySum("input", 20., :min)]) # defaultmodifier -> mass
        
        set_objective(sim(c).model, MIN_SENSE, balance(c, :output, energy))
        JuMP.set_silent(sim(c).model)
        JuMP.optimize!(sim(c).model)
        _c = _extract(c)

        @test isapprox(balance(_c, :input, mass), 20.)

    end

    let 

        c = makecomp([FixedCapacity("input", mass, 5.), YearlySum("input", 20., :max)]) # defaultmodifier -> mass
        
        set_objective(sim(c).model, MAX_SENSE, balance(c, :output, energy))
        JuMP.set_silent(sim(c).model)
        JuMP.optimize!(sim(c).model)
        _c = _extract(c)

        @test isapprox(balance(_c, :input, mass), 20.)

    end

    let 

        c = makecomp([FixedCapacity("input", mass, 5.), YearlySum("input", 20., :max)]) # defaultmodifier -> mass
        
        set_objective(sim(c).model, MIN_SENSE, balance(c, :output, energy))
        JuMP.set_silent(sim(c).model)
        JuMP.optimize!(sim(c).model)
        _c = _extract(c)

        @test isapprox(balance(_c, :input, mass), 0.)

    end
end

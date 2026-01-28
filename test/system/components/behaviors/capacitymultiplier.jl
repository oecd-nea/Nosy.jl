using Nosy: mass, energy
using Nosy: Sim, TimeMesh, sim
using Nosy: buildbehavior
using Nosy: CapacityMultiplier, CapacityMultiplierBehavior
using Nosy: FixedCapacity, VariableCapacity
using Nosy: BasicConverter, ProfileSource
using Nosy: MassCarrier, EnergyCarrier
using Nosy: Component
using Nosy: balance, _balance
using JuMP: AffExpr
import JuMP
using ArgCheck: ArgumentError

using HiGHS: Optimizer
using Test

@testset "CapacityMultiplier" begin

    tsim(model=nothing) = Sim(JuMP.Model(model), mesh=TimeMesh(fill(1//2, 10)))

    function makeconv(model=nothing)
        s = tsim(model)
        JuMP.set_silent(s.model)    
        mc = MassCarrier("m", s, energy=[1,2,3,4,5])
        ec = EnergyCarrier("e", s)
        d = BasicConverter(
            mc,
            ec,
        )        
        return d
    end

    @test_throws ArgumentError CapacityMultiplier("input", -0.5) # negative number
    @test_throws ArgumentError CapacityMultiplier("input", [0.1, 0.5, -0.5]) # series has a negative number

    # testing compatibility with different types of multipliers
    let s = tsim()

        c = Component("comp", makeconv(), [])

        # scalar multiplier
        let cb = buildbehavior(c, CapacityMultiplier("input", 0.5))

            @test cb isa CapacityMultiplierBehavior{AffExpr, Float64} # verifying parametric type is GenericAffExpr when building through component
        
        end

        # ~hourly multiplier
        let cb = buildbehavior(c, CapacityMultiplier("input", fill(0.5, 5)))

            @test cb isa CapacityMultiplierBehavior{AffExpr, Vector{Float64}}

        end

        # ~stepwise multiplier
        let cb = buildbehavior(c, CapacityMultiplier("input", fill(0.5, 10)))

            @test cb isa CapacityMultiplierBehavior{AffExpr, Vector{Float64}}

        end

        # inconsistent vector size (not scalar / hourly / stepwise)
        @test_throws ArgumentError buildbehavior(c, CapacityMultiplier("input", fill(0.5, 6)))

    end

    # test with fixed capacity + converter
    let
        fx = FixedCapacity("input", mass, 10.)
        cm = CapacityMultiplier("input", 0.1:0.1:1.0)

        c = Component("comp", makeconv(Optimizer), [fx, cm])

        # test: maximize sum of balance of input mass flow of c (no other constraints than capacity)
        # expected result: reaches [0.6... 1.0] * 10. at each timestep
        JuMP.set_objective(sim(c).model, JuMP.MAX_SENSE, balance(c, :input, mass, collapse=true, aggregate=true))
        JuMP.optimize!(sim(c).model)
        @test all(isapprox.(JuMP.value.(_balance(c, :input, mass, collapse=false, aggregate=true)), collect(0.1:0.1:1.0) * 10.))

    end

    # test with variable capacity
    let
        fx = VariableCapacity("input", mass, lb=5., ub=10.)
        cm = CapacityMultiplier("input", 0.1:0.1:1.0)

        c = Component("comp", makeconv(Optimizer), [fx, cm])

        # test: maximize sum of balance of input mass flow of c (no other constraints than capacity)
        # expected result: reaches [0.6... 1.0] * 10. at each timestep
        JuMP.set_objective(sim(c).model, JuMP.MAX_SENSE, balance(c, :input, mass, collapse=true, aggregate=true))
        JuMP.optimize!(sim(c).model)
        @test all(isapprox.(JuMP.value.(_balance(c, :input, mass, collapse=false, aggregate=true)), collect(0.1:0.1:1.0) * 10.))

    end

    # test with variable or fixed capacity + incompatible port name
    let
        vc = VariableCapacity("input", mass, lb=5., ub=10.)
        fc = FixedCapacity("input", mass, 10.)
        cm = CapacityMultiplier("output", 0.1:0.1:1.0)

        @test_throws AssertionError Component("comp", makeconv(Optimizer), [vc, cm])
        @test_throws AssertionError Component("comp", makeconv(Optimizer), [fc, cm])

    end   

    # test multiple capacities, one is compatible
    let
        vc = VariableCapacity("input", mass, lb=5., ub=10.)
        fc = FixedCapacity("output", energy, 7.)
        cm = CapacityMultiplier("output", 0.1:0.1:1.0)

        c = Component("comp", makeconv(Optimizer), [vc, fc, cm])
        # test: maximize sum of balance of input mass flow of c (no other constraints than capacity)
        # expected result: reaches [0.6... 1.0] * 7. at each timestep
        JuMP.set_objective(sim(c).model, JuMP.MAX_SENSE, balance(c, :input, mass, collapse=true, aggregate=true))
        JuMP.optimize!(sim(c).model)
        @test all(isapprox.(JuMP.value.(_balance(c, :input, mass, collapse=false, aggregate=true)), collect(0.1:0.1:1.0) * 7.))

    end   

    # profile source, not compatible with capacity multiplier
    function makeprof(model=nothing)
        s = tsim(model)
        JuMP.set_silent(s.model)
        mc = MassCarrier("m", s, energy=[1,2,3,4,5])
        d = ProfileSource(mc, ones(5))        
        return d
    end


    # test with fixed or variable capacity + profilesource: not compatible
    let prof = makeprof(Optimizer)
        fc = FixedCapacity("output", mass, 10.)
        vc = VariableCapacity("output", mass, lb=5, ub=10)
        cm = CapacityMultiplier("output", 0.1:0.1:1.0)

        @test_throws AssertionError Component("comp", prof, [fc, cm])
        @test_throws AssertionError Component("comp", prof, [vc, cm])

    end

end

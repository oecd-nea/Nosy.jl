using Nosy: mass, energy, co2
using Nosy: Sim, TimeMesh, nvariables, nconstraints, sim
using Nosy: buildbehavior
using Nosy: FixedComposedCapacity, _capacity, _nbunits, nbunits
using Nosy: CapacityMultiplier, capacity
using Nosy: BasicConverter, ProfileSource
using Nosy: MassCarrier, EnergyCarrier
using Nosy: LinkedJointFlow, balance, _balance
using Nosy: Component
using JuMP: Model
import JuMP
using HiGHS: Optimizer
using ArgCheck: ArgumentError
using Test

@testset "FixedComposedCapacity" begin

    tsim(model=nothing) = Sim(JuMP.Model(model), mesh=TimeMesh(fill(1//2, 10)))

    function makecomp(vbehavior=[]; model=nothing)
        s = tsim(model)
        JuMP.set_silent(s.model)
        mc = MassCarrier("m", s, energy=[1,2,3,4,5])
        ec = EnergyCarrier("e", s)
        d = BasicConverter(mc, ec)
        c = Component("comp", d, vbehavior)
        return c
    end

    @test_throws ArgumentError FixedComposedCapacity(String[], mass, 5.) # empty target list is invalid
    @test_throws ArgumentError FixedComposedCapacity(["input", "input"], mass, 5.) # duplicate target ports are not allowed
    @test_throws ArgumentError FixedComposedCapacity(["input", "output"], mass, -1.) # capacity cannot be negative
    @test_throws ArgumentError FixedComposedCapacity(["input", "output"], mass, 5., unitsize=-1.) # unitsize must be strictly positive

    let m = makecomp()

        c = FixedComposedCapacity(
            ["input", "output"],
            energy,
            5,
        )

        b = buildbehavior(m, c)

        @test b.data.pname == ["input", "output"]
        @test _capacity(b) == 5.
        @test isnothing(_nbunits(b))

    end

    let m = makecomp()

        c = FixedComposedCapacity(
            ["input", "output"],
            energy,
            5,
            unitsize=2.5,
        )

        b = buildbehavior(m, c)

        @test _capacity(b) == 5.
        @test _nbunits(b) == 2.

    end

    let m = makecomp()
        c = FixedComposedCapacity(
            ["input", "nonexistent"],
            energy,
            5.,
        )
        @test_throws ArgumentError buildbehavior(m, c) # one target port does not exist on the component
    end

    let m = makecomp()
        c = FixedComposedCapacity(
            ["input", "output"],
            co2,
            5.,
        )
        @test_throws ArgumentError buildbehavior(m, c) # selected modifier is incompatible with targeted ports
    end

    let c = makecomp([FixedComposedCapacity(["input", "output"], energy, 5.)])
        @test nvariables(sim(c)) == 10
        @test nconstraints(sim(c)) == 20
        @test isnothing(nbunits(c))
    end

    let c = makecomp([FixedComposedCapacity(["input", "output"], energy, 5., unitsize=2.5)])
        @test nvariables(sim(c)) == 10
        @test nconstraints(sim(c)) == 20
        @test nbunits(c) == 2.
    end

    function makecompwjoint(vbehavior=[]; model=nothing)
        s = tsim(model)
        JuMP.set_silent(s.model)
        mc = MassCarrier("m", s, energy=[1,2,3,4,5])
        ec = EnergyCarrier("e", s)
        d = BasicConverter(mc, ec)
        j = LinkedJointFlow("jflow", mc, :output, "input", x -> x)
        c = Component("comp", d, [j, vbehavior...])
        return c
    end

    let
        cap = FixedComposedCapacity(["input", "jflow"], mass, 10.)
        cm = CapacityMultiplier("input", 0.1:0.1:1.0)
        c = makecompwjoint([cap, cm], model=Optimizer)

        JuMP.set_objective(sim(c).model, JuMP.MAX_SENSE, balance(c, :input, mass, collapse=true, aggregate=true))
        JuMP.optimize!(sim(c).model)
        @test all(isapprox.(JuMP.value.(_balance(c, :input, mass, collapse=false, aggregate=true)), collect(0.1:0.1:1.0) * 5.))

        # capacity(c; multiplier=true) should apply the matching multiplier for composed capacities
        _cap = capacity(c)
        _capmult = capacity(c, multiplier=true)
        @test all(isapprox.(JuMP.value.(_capmult.data), collect(0.1:0.1:1.0) .* _cap))
    end

    let
        cap = FixedComposedCapacity(["input", "jflow"], mass, 10.)
        cm = CapacityMultiplier("output", 0.1:0.1:1.0)
        @test_throws AssertionError makecompwjoint([cap, cm], model=Optimizer) # multiplier does not target any composed-capacity port
    end

    let
        cap = FixedComposedCapacity(["input", "jflow"], mass, 10.)
        cm1 = CapacityMultiplier("input", 0.1:0.1:1.0)
        cm2 = CapacityMultiplier("jflow", 0.1:0.1:1.0)
        @test_throws AssertionError makecompwjoint([cap, cm1, cm2], model=Optimizer) # multiple matching multipliers are intentionally unsupported
    end

    function makeprofilesource(vbehavior=[]; model=nothing)
        s = tsim(model)
        mc = MassCarrier("m", s, energy=[1,2,3,4,5])
        d = ProfileSource(mc, [0.1,0.2,0.3,0.4,0.5])
        c = Component("profile", d, vbehavior)
        return c
    end

    let cap = FixedComposedCapacity(["output"], mass, 5.)
        @test_throws ArgumentError makeprofilesource([cap]) # profile source is intentionally unsupported for composed capacity
    end

end

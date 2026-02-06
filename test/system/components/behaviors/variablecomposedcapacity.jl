using Nosy: mass, energy, co2
using Nosy: Sim, TimeMesh, nvariables, nconstraints, sim
using Nosy: buildbehavior
using Nosy: VariableComposedCapacity, _capacity
using Nosy: VariableCapacity
using Nosy: CapacityMultiplier
using Nosy: UnitCommitment
using Nosy: BasicConverter, ProfileSource
using Nosy: MassCarrier, EnergyCarrier
using Nosy: LinkedJointFlow, balance, _balance, capacity
using Nosy: Component
using JuMP: Model, GenericAffExpr, lower_bound, has_upper_bound
import JuMP
using HiGHS: Optimizer
using ArgCheck: ArgumentError
using Test

@testset "VariableComposedCapacity" begin

    tsim(model=nothing) = Sim(JuMP.Model(model), mesh=TimeMesh(fill(1//2, 10)))

    getvariable(e::GenericAffExpr) = first(e.terms)[1]

    function makecomp(vbehavior=[]; model=nothing)
        s = tsim(model)
        JuMP.set_silent(s.model)
        mc = MassCarrier("m", s, energy=[1,2,3,4,5])
        ec = EnergyCarrier("e", s)
        d = BasicConverter(mc, ec)
        c = Component("comp", d, vbehavior)
        return c
    end

    @test_throws ArgumentError VariableComposedCapacity(String[], mass) # empty target list is invalid
    @test_throws ArgumentError VariableComposedCapacity(["input", "input"], mass) # duplicate target ports are not allowed
    @test_throws ArgumentError VariableComposedCapacity(["input", "output"], mass, lb=-1.) # capacity lower bound cannot be negative
    @test_throws ArgumentError VariableComposedCapacity(["input", "output"], mass, lb=2., ub=1.) # lower bound must not exceed upper bound

    let m = makecomp()

        c = VariableComposedCapacity(
            ["input", "output"],
            energy,
            lb = 5,
            ub = Inf64,
        )

        b = buildbehavior(m, c)

        @test b.data.pname == ["input", "output"]
        @test _capacity(b) isa GenericAffExpr

        var = getvariable(_capacity(b))
        @test lower_bound(var) == 5.
        @test !has_upper_bound(var)

    end

    let m = makecomp()
        c = VariableComposedCapacity(
            ["input", "nonexistent"],
            energy,
            lb = 5,
            ub = Inf64,
        )
        @test_throws ArgumentError buildbehavior(m, c) # one target port does not exist on the component
    end

    let m = makecomp()
        c = VariableComposedCapacity(
            ["input", "output"],
            co2,
            lb = 5,
            ub = Inf64,
        )
        @test_throws ArgumentError buildbehavior(m, c) # selected modifier is incompatible with targeted ports
    end

    let c = makecomp([VariableComposedCapacity(["input", "output"], energy, lb=5, ub=Inf64)])
        @test nvariables(sim(c)) == 11
        @test nconstraints(sim(c)) == 21
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
        cap = VariableComposedCapacity(["input", "jflow"], mass, lb=0., ub=10.)
        cm = CapacityMultiplier("input", 0.1:0.1:1.0)
        c = makecompwjoint([cap, cm], model=Optimizer)

        JuMP.set_objective(sim(c).model, JuMP.MAX_SENSE, balance(c, :input, mass, collapse=true, aggregate=true))
        JuMP.optimize!(sim(c).model)
        @test all(isapprox.(JuMP.value.(_balance(c, :input, mass, collapse=false, aggregate=true)), collect(0.1:0.1:1.0) * 5.))

        # capacity(c; multiplier=true) should apply the matching multiplier for composed capacities
        _cap = capacity(c)
        _capmult = capacity(c, multiplier=true)
        @test all(isapprox.(JuMP.value.(_capmult.data), collect(0.1:0.1:1.0) .* JuMP.value(_cap)))
    end

    let
        cap = VariableComposedCapacity(["input", "jflow"], mass, lb=0., ub=10.)
        cm = CapacityMultiplier("output", 0.1:0.1:1.0)
        @test_throws AssertionError makecompwjoint([cap, cm], model=Optimizer) # multiplier does not target any composed-capacity port
    end

    let
        cap = VariableComposedCapacity(["input", "jflow"], mass, lb=0., ub=10.)
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

    let cap = VariableComposedCapacity(["output"], mass, lb=5., ub=Inf64)
        @test_throws ArgumentError makeprofilesource([cap]) # profile source is intentionally unsupported for composed capacity
    end

    let
        cap = VariableComposedCapacity(["input", "jflow"], mass, lb=0., ub=10., unitsize=1.)
        uc = UnitCommitment("input", 0.2)
        @test_throws AssertionError makecompwjoint([cap, uc], model=Optimizer) # UC must fail early on ports covered by composed capacity
    end

    let
        vc = VariableCapacity("input", mass, lb=0., ub=10., unitsize=1.)
        uc = UnitCommitment("input", 0.2)
        c0 = makecomp([vc, uc], model=Optimizer)
        JuMP.set_objective(sim(c0).model, JuMP.MAX_SENSE, balance(c0, :input, mass, collapse=true, aggregate=true))
        JuMP.optimize!(sim(c0).model)

        ucb = only([b for b in c0.behaviors if b isa Nosy.AbstractFleetUnitCommitmentBehavior])
        ucfromini = UnitCommitment(Nosy._extract(ucb))

        cap = VariableComposedCapacity(["input", "output"], energy, lb=0., ub=10., unitsize=1.)
        @test_throws AssertionError makecomp([cap, ucfromini], model=Optimizer) # FleetUnitCommitmentFromIni must fail early on ports covered by composed capacity
    end

end

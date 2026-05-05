using Nosy: MassCarrier, EnergyCarrier
using Nosy: mass, energy
using Nosy: Sim, TimeMesh
using Nosy: BasicConverter
using Nosy: Component, Node, Snapshot, connect!
using Nosy: Hourly
using Nosy: balance, _balance
using JuMP: Model, AffExpr
using Test

@testset "Snapshot balance" begin

    tsim() = Sim(Model(), mesh=TimeMesh(fill(1//2, 10)))

    function makesnapshot()
        s = tsim()
        mc = MassCarrier("m", s, energy=[1,2,3,4,5])
        ec = EnergyCarrier("e", s)
        c = Component("comp", BasicConverter(mc, ec))
        n = Node("mass", mc)
        snap = Snapshot(s)
        connect!(snap, c, n, "input")
        return snap, c, n
    end

    let (snap, c, n) = makesnapshot()

        # Private snapshot balance delegates to component balance unchanged.
        cb = _balance(snap, "comp", :input, mass, collapse=false, aggregate=false)
        @test cb == _balance(c, :input, mass, collapse=false, aggregate=false)

        # Public snapshot balance converts Stepwise entries to Hourly.
        hb = balance(snap, "comp", :input, mass, collapse=false, aggregate=false)
        @test hb isa Dict
        @test hb["input"] isa Hourly
        @test hb["input"] == Hourly(cb["input"])

        # Aggregate public balance converts a single Stepwise series to Hourly.
        ab = balance(snap, "comp", :input, mass, collapse=false, aggregate=true)
        @test ab isa Hourly
        @test ab == Hourly(_balance(c, :input, mass, collapse=false, aggregate=true))

        # Collapsed balances are scalars/expressions and should not be wrapped.
        collapsed = balance(snap, "comp", :input, mass, collapse=true, aggregate=true)
        @test collapsed isa AffExpr
        @test collapsed == _balance(c, :input, mass, collapse=true, aggregate=true)

        # Node names are resolved after component names and use node balance.
        nb = _balance(snap, "mass", :output, mass, collapse=false, aggregate=false)
        @test nb == _balance(n, :output, mass, collapse=false, aggregate=false)

        hnb = balance(snap, "mass", :output, mass, collapse=false, aggregate=false)
        @test hnb["comp"] isa Hourly
        @test hnb["comp"] == Hourly(nb["comp"])

        @test_throws AssertionError _balance(snap, "missing", :input, mass)

    end

end

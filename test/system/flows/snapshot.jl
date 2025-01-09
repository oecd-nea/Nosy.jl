using Nosy: Model
using Nosy: MassCarrier, EnergyCarrier
using Nosy: Demand, BasicConverter, DispatchableSource
using Nosy: VariableCost
using Nosy: mass, energy
using Nosy: Sim, TimeMesh
using Nosy: Component, Node, Snapshot, connect!
using Nosy: flow
using Nosy: extract

using JuMP: set_silent, is_solved_and_feasible
using HiGHS

@testset "Snapshot flow" begin

    function makesnapshot()
        sim = Sim(TimeMesh(fill(1//1,8760)), Model(HiGHS.Optimizer))
        set_silent(sim.model)

        mc = MassCarrier("mc", sim, energy=3.)
        mc2 = MassCarrier("mc2", sim)
        ec = EnergyCarrier("ec", sim)

        s = Snapshot(sim)

        mn = Node("mn", mc, rule=:curtailed)
        mn2 = Node("mn2", mc2, rule=:curtailed)
        en = Node("en", ec, rule=:curtailed)

        # source
        dsd = DispatchableSource(mc)
        dsb = [
            VariableCost(:fuel, "output", mass, 1.),
            LinkedJointFlow("mc2", mc2, :output, "output", x->0.3*x),
        ]
        ds = Component("source", dsd, dsb)
        connect!(s, ds, mn)
        connect!(s, ds, mn2)

        # conv
        cd = BasicConverter(mc, ec, ratio=0.5, modifier=energy)
        c = Component("converter", cd, [])
        connect!(s, c, mn)
        connect!(s, c, en)

        # demand
        dd = Demand(ec, 1:8760)
        d = Component("demand", dd, [])
        connect!(s, d, en)

        optimize!(s, cost)

        @assert is_solved_and_feasible(sim.model)

        return extract(s)
    end

    let s = makesnapshot()

        @test_throws ArgumentError flow(s, "demand", :input, energy, hour=1, day=1)
        @test_throws ArgumentError flow(s, "demand", :input, energy, hour=1, month=1)
        @test_throws ArgumentError flow(s, "demand", :input, energy, day=1, month=1)

        @test_throws ArgumentError flow(s, "demand", :input, energy, hour=1.5)

        @test_throws ArgumentError flow(s, "demand", :input, energy, day=1.5)
        @test_throws ArgumentError flow(s, "demand", :input, energy, day=0)
        @test_throws ArgumentError flow(s, "demand", :input, energy, day=366)

        @test_throws ArgumentError flow(s, "demand", :input, energy, month=1.5)
        @test_throws ArgumentError flow(s, "demand", :input, energy, month=0)
        @test_throws ArgumentError flow(s, "demand", :input, energy, month=13) 

        @test_throws ArgumentError flow(s, "other", :input, energy)

        """               
        Analytic verification of most flows
        """

        # not specifying pname
        @test all(isapprox.(flow(s, "demand", :input, energy, hour=h), h+1) for h in 0:8759)
        @test isapprox(flow(s, "demand", :input, energy, day=1), sum(1:24))
        @test isapprox(sum(flow(s, "demand", :input, energy, day=d) for d in 1:365), sum(1:8760))
        @test isapprox(flow(s, "demand", :input, energy, month=1), sum(1:(24*31)))
        @test isapprox(sum(flow(s, "demand", :input, energy, month=m) for m in 1:12), sum(1:8760))
        @test isapprox(flow(s, "demand", :input, energy), sum(1:8760))

        @test all(isapprox.(flow(s, "converter", :input, energy, hour=h), (h+1)*2) for h in 0:8759)
        @test isapprox(flow(s, "converter", :input, energy, day=1), sum(1:24)*2)
        @test isapprox(sum(flow(s, "converter", :input, energy, day=d) for d in 1:365), sum(1:8760)*2)
        @test isapprox(flow(s, "converter", :input, energy, month=1), sum(1:(24*31))*2)
        @test isapprox(sum(flow(s, "converter", :input, energy, month=m) for m in 1:12), sum(1:8760)*2)
        @test isapprox(flow(s, "converter", :input, energy), sum(1:8760)*2)

        @test all(isapprox.(flow(s, "converter", :input, mass, hour=h), (h+1)*2/3) for h in 0:8759)
        @test isapprox(flow(s, "converter", :input, mass, day=1), sum(1:24)*2/3)
        @test isapprox(sum(flow(s, "converter", :input, mass, day=d) for d in 1:365), sum(1:8760)*2/3)
        @test isapprox(flow(s, "converter", :input, mass, month=1), sum(1:(24*31))*2/3)
        @test isapprox(sum(flow(s, "converter", :input, mass, month=m) for m in 1:12), sum(1:8760)*2/3)
        @test isapprox(flow(s, "converter", :input, mass), sum(1:8760)*2/3)

        @test all(isapprox.(flow(s, "source", :output, mass, hour=h), (h+1)*2/3*1.3) for h in 0:8759)
        @test isapprox(flow(s, "source", :output, mass, day=1), sum(1:24)*2/3*1.3)
        @test isapprox(sum(flow(s, "source", :output, mass, day=d) for d in 1:365), sum(1:8760)*2/3*1.3)
        @test isapprox(flow(s, "source", :output, mass, month=1), sum(1:(24*31))*2/3*1.3)
        @test isapprox(sum(flow(s, "source", :output, mass, month=m) for m in 1:12), sum(1:8760)*2/3*1.3)
        @test isapprox(flow(s, "source", :output, mass), sum(1:8760)*2/3*1.3)

        @test all(isapprox.(flow(s, "en", :output, energy, hour=h), h+1) for h in 0:8759)
        @test isapprox(flow(s, "en", :output, energy, day=1), sum(1:24))
        @test isapprox(sum(flow(s, "en", :output, energy, day=d) for d in 1:365), sum(1:8760))
        @test isapprox(flow(s, "en", :output, energy, month=1), sum(1:(24*31)))
        @test isapprox(sum(flow(s, "en", :output, energy, month=m) for m in 1:12), sum(1:8760))
        @test isapprox(flow(s, "en", :output, energy), sum(1:8760))


        # specifying pname
        @test all(isapprox.(flow(s, "demand", "input", :input, energy, hour=h), h+1) for h in 0:8759)
        @test isapprox(flow(s, "demand", "input", :input, energy, day=1), sum(1:24))
        @test isapprox(sum(flow(s, "demand", "input", :input, energy, day=d) for d in 1:365), sum(1:8760))
        @test isapprox(flow(s, "demand", "input", :input, energy, month=1), sum(1:(24*31)))
        @test isapprox(sum(flow(s, "demand", "input", :input, energy, month=m) for m in 1:12), sum(1:8760))
        @test isapprox(flow(s, "demand", "input", :input, energy), sum(1:8760))

        @test all(isapprox.(flow(s, "converter", "input", :input, energy, hour=h), (h+1)*2) for h in 0:8759)
        @test isapprox(flow(s, "converter", "input", :input, energy, day=1), sum(1:24)*2)
        @test isapprox(sum(flow(s, "converter", "input", :input, energy, day=d) for d in 1:365), sum(1:8760)*2)
        @test isapprox(flow(s, "converter", "input", :input, energy, month=1), sum(1:(24*31))*2)
        @test isapprox(sum(flow(s, "converter", "input", :input, energy, month=m) for m in 1:12), sum(1:8760)*2)
        @test isapprox(flow(s, "converter", "input", :input, energy), sum(1:8760)*2)

        @test all(isapprox.(flow(s, "converter", "input", :input, mass, hour=h), (h+1)*2/3) for h in 0:8759)
        @test isapprox(flow(s, "converter", "input", :input, mass, day=1), sum(1:24)*2/3)
        @test isapprox(sum(flow(s, "converter", "input", :input, mass, day=d) for d in 1:365), sum(1:8760)*2/3)
        @test isapprox(flow(s, "converter", "input", :input, mass, month=1), sum(1:(24*31))*2/3)
        @test isapprox(sum(flow(s, "converter", "input", :input, mass, month=m) for m in 1:12), sum(1:8760)*2/3)
        @test isapprox(flow(s, "converter", "input", :input, mass), sum(1:8760)*2/3)

        @test all(isapprox.(flow(s, "source", "output", :output, mass, hour=h), (h+1)*2/3) for h in 0:8759)
        @test isapprox(flow(s, "source", "output", :output, mass, day=1), sum(1:24)*2/3)
        @test isapprox(sum(flow(s, "source", "output", :output, mass, day=d) for d in 1:365), sum(1:8760)*2/3)
        @test isapprox(flow(s, "source", "output", :output, mass, month=1), sum(1:(24*31))*2/3)
        @test isapprox(sum(flow(s, "source", "output", :output, mass, month=m) for m in 1:12), sum(1:8760)*2/3)
        @test isapprox(flow(s, "source", "output", :output, mass), sum(1:8760)*2/3)

        @test all(isapprox.(flow(s, "source", "mc2", :output, mass, hour=h), (h+1)*2/3*0.3) for h in 0:8759)
        @test isapprox(flow(s, "source", "mc2", :output, mass, day=1), sum(1:24)*2/3*0.3)
        @test isapprox(sum(flow(s, "source", "mc2", :output, mass, day=d) for d in 1:365), sum(1:8760)*2/3*0.3)
        @test isapprox(flow(s, "source", "mc2", :output, mass, month=1), sum(1:(24*31))*2/3*0.3)
        @test isapprox(sum(flow(s, "source", "mc2", :output, mass, month=m) for m in 1:12), sum(1:8760)*2/3*0.3)
        @test isapprox(flow(s, "source", "mc2", :output, mass), sum(1:8760)*2/3*0.3)

        @test all(isapprox.(flow(s, "en", "demand", :output, energy, hour=h), h+1) for h in 0:8759)
        @test isapprox(flow(s, "en", "demand", :output, energy, day=1), sum(1:24))
        @test isapprox(sum(flow(s, "en", "demand", :output, energy, day=d) for d in 1:365), sum(1:8760))
        @test isapprox(flow(s, "en", "demand", :output, energy, month=1), sum(1:(24*31)))
        @test isapprox(sum(flow(s, "en", "demand", :output, energy, month=m) for m in 1:12), sum(1:8760))
        @test isapprox(flow(s, "en", "demand", :output, energy), sum(1:8760))

    end

end
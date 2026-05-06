using Nosy: MassCarrier, EnergyCarrier, PowerCarrier
using Nosy: mass, energy, co2
using Nosy: Sim, TimeMesh
using Nosy: PortRef
using Nosy: BasicConverter, DispatchableSource, Demand, DCLine
using Nosy: Component, Node, Snapshot, connect!
using Nosy: FixedCapacity, VariableCost
using Nosy: _flow, flow
using Nosy: _extract, extract, optimize!, cost
using Nosy: balance

using JuMP: Model, @constraint, set_objective, set_silent
import JuMP
import JuMP: MAX_SENSE

using HiGHS
using Test

@testset "Component flow" begin

    
    tsim() = Sim(Model(HiGHS.Optimizer), mesh=TimeMesh(fill(1//2, 10)))

    function makecomp1(vbehavior)
        s = tsim()    
        mc = MassCarrier("m", s, energy=1:10)
        ec = EnergyCarrier("e", s)
        d = BasicConverter(mc, ec, ratio=0.5)
        c = Component("comp", d, vbehavior)
        @constraint(s.model, c.s.input[PortRef("comp", "input")].series.data .== collect(1:10))
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
        
        @test_throws AssertionError _flow(c, "input", co2, 1) # CO2 modifier not compatible
        @test_throws AssertionError _flow(c, "noname", mass, 1) # no port named "noname"

        @test all((_flow(c, :input, mass, step) for step in 1:10) .== (1:10))
        @test all((_flow(c, :output, energy, step) for step in 1:10) .== ((1:10) * 0.5))

        @test all((_flow(c, :input, energy, step) for step in 1:10) .== ((1:10) .* (1:10)))

        @test all(iszero(_flow(c, :output, co2, step)) for step in 1:10)

        

        # flow at a given hour

        @test all((flow(c, "input", mass, h) for h in 0:4) .== 1:2:10)
        @test all((flow(c, "input", energy, h) for h in 0:4) .== ((1:2:10) .* (1:2:10)))
        @test all((flow(c, "output", energy, h) for h in 0:4) .== ((1:2:10) * 0.5))
        
        @test_throws AssertionError flow(c, "input", co2, 1) # CO2 modifier not compatible
        @test_throws AssertionError flow(c, "noname", mass, 1) # no port named "noname"

        @test all((flow(c, :input, mass, h) for h in 0:4) .== (1:2:10))
        @test all((flow(c, :output, energy, h) for h in 0:4) .== ((1:2:10) * 0.5))

        @test all((flow(c, :input, energy, h) for h in 0:4) .== ((1:2:10) .* (1:2:10)))

        @test all(iszero(_flow(c, :output, co2, h)) for h in 0:4)

    end

    let
        s = Sim(Model(HiGHS.Optimizer), mesh=TimeMesh(fill(1//1, 4)))
        pc = PowerCarrier("electricity", s)
        snap = Snapshot(s)

        n1 = Node("n1", pc)
        n2 = Node("n2", pc)

        src = Component("src", DispatchableSource(pc), [
            FixedCapacity("output", energy, 4.0),
            VariableCost(:fuel, "output", energy, 1.0),
        ])
        dmd = Component("dmd", Demand(pc, fill(1.0, 4)), [])
        line = Component("line", DCLine(pc, pc), [
            FixedCapacity("from_out", energy, 10.0),
            FixedCapacity("to_out", energy, 10.0),
        ])

        connect!(snap, src, n1)
        connect!(snap, dmd, n2)
        connect!(snap, line, n1, "from_out")
        connect!(snap, line, n1, "from_in")
        connect!(snap, line, n2, "to_in")
        connect!(snap, line, n2, "to_out")

        set_silent(s.model)
        optimize!(snap, cost(snap))

        ex = extract(snap)
        eline = ex.components["line"]
        en1 = ex.nodes["n1"]
        en2 = ex.nodes["n2"]

        @test all(flow(eline, "from_out", energy, h) ≈ -1.0 for h in 0:3)
        @test all(flow(eline, "to_out", energy, h) ≈ 1.0 for h in 0:3)
        @test all(iszero(flow(eline, "from_in", energy, h)) for h in 0:3)
        @test all(iszero(flow(eline, "to_in", energy, h)) for h in 0:3)

        @test all(iszero.(_flow(eline, :input, energy, step)) for step in 1:4)
        @test all(iszero.(_flow(eline, :output, energy, step)) for step in 1:4)

        line_outputs = balance(eline, :output, energy; collapse=false, aggregate=false)
        @test line_outputs["from_out"].data ≈ fill(-1.0, 4)
        @test line_outputs["to_out"].data ≈ fill(1.0, 4)
        @test balance(eline, :output, energy; collapse=false, aggregate=true).data ≈ zeros(4)
        @test balance(eline, :input, energy; collapse=false, aggregate=true).data ≈ zeros(4)

        n1_inputs = balance(en1, :input, energy; collapse=false, aggregate=false)
        @test n1_inputs["src"].data ≈ fill(1.0, 4)
        @test n1_inputs["line"].data ≈ fill(-1.0, 4)
        @test balance(en1, :input, energy; collapse=false, aggregate=true).data ≈ zeros(4)
        @test balance(en1, :output, energy; collapse=false, aggregate=true).data ≈ zeros(4)

        n2_inputs = balance(en2, :input, energy; collapse=false, aggregate=false)
        @test n2_inputs["line"].data ≈ fill(1.0, 4)
        @test balance(en2, :output, energy; collapse=false, aggregate=false)["dmd"].data ≈ fill(1.0, 4)
    end

end

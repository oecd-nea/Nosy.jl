using Nosy: Model
using Nosy: PowerCarrier
using Nosy: Demand, DispatchableSource, ACLine, DCLine
using Nosy: VariableCost, FixedCapacity
using Nosy: energy
using Nosy: Sim, TimeMesh
using Nosy: Component, Node, Snapshot, connect!
using Nosy: extract, optimize!, cost
using Nosy: _transmissionbalance, balance

using JuMP: set_silent, is_solved_and_feasible
using HiGHS

@testset "KVL" begin
    # single AC line without cycles: verify basic power flow works when no KVL constraint applies
    let
        sim = Sim(Model(HiGHS.Optimizer), mesh=TimeMesh(fill(1//1, 24)))
        set_silent(sim.model)

        pc = PowerCarrier("electricity", sim)
        s  = Snapshot(sim)

        n1 = Node("n1", pc, rule=:default)
        n2 = Node("n2", pc, rule=:default)

        src = Component("src", DispatchableSource(pc), [
            VariableCost(:fuel, "output", energy, 1.0)
        ])
        connect!(s, src, n1)

        dmd = Component("dmd", Demand(pc, fill(1.0, 24)), [])
        connect!(s, dmd, n2)

        l = Component("acline", ACLine(pc, pc, 1.0), [
            FixedCapacity("from_out", energy, 1.0e6),  
            FixedCapacity("to_out", energy, 1.0e6),
        ])

        connect!(s, l, n1, "from_out")
        connect!(s, l, n1, "from_in")
        connect!(s, l, n2, "to_in")
        connect!(s, l, n2, "to_out")

        optimize!(s, cost)
        @assert is_solved_and_feasible(sim.model)

        # After optimization, the generator’s hourly output must equal the sum of demand time series (KCL check)    
        ex = Nosy.extract(s)
        src_hourly = balance(ex, "src", :output, energy; collapse=false, aggregate=true)  
        dmd_hourly = balance(ex, "dmd", :input, energy; collapse=false, aggregate=true) 
        @test all(isapprox.(src_hourly.data, dmd_hourly.data; atol=1e-6))
    end

    # single DC line: verify DC lines are excluded from KVL constraint (KVL only applies to AC circuits)
    let
        sim = Sim(Model(HiGHS.Optimizer), mesh=TimeMesh(fill(1//1, 24)))
        set_silent(sim.model)

        pc = PowerCarrier("electricity", sim)
        s  = Snapshot(sim)

        n1 = Node("n1", pc, rule=:default)
        n2 = Node("n2", pc, rule=:default)

        src = Component("src", DispatchableSource(pc), [
            VariableCost(:fuel, "output", energy, 1.0)
        ])
        connect!(s, src, n1)

        dmd = Component("dmd", Demand(pc, fill(1.0, 24)), [])
        connect!(s, dmd, n2)

        l = Component("dcline", DCLine(pc, pc), [
            FixedCapacity("from_out", energy, 1.0e6),
            FixedCapacity("to_out", energy, 1.0e6),
        ])

        connect!(s, l, n1, "from_out")
        connect!(s, l, n1, "from_in")
        connect!(s, l, n2, "to_in")
        connect!(s, l, n2, "to_out")

        optimize!(s, cost)
        @assert is_solved_and_feasible(sim.model)

        # After optimization, the generator’s hourly output must equal the sum of demand time series (KCL check)    
        ex = Nosy.extract(s)  
        src_hourly = balance(ex, "src", :output, energy; collapse=false, aggregate=true)
        dmd_hourly = balance(ex, "dmd", :input, energy; collapse=false, aggregate=true)  
        @test all(isapprox.(src_hourly.data, dmd_hourly.data; atol=1e-6))
    end
    
    # three-node AC loop: verify KVL constraint holds (sum(flow_ij / B_ij) = 0) and flow antisymmetry
    let
        sim = Sim(Model(HiGHS.Optimizer), mesh=TimeMesh(fill(1//1, 24)))
        set_silent(sim.model)

        pc = PowerCarrier("electricity", sim)
        s  = Snapshot(sim)

        n1 = Node("n1", pc, rule=:default)
        n2 = Node("n2", pc, rule=:default)
        n3 = Node("n3", pc, rule=:default)

        src  = Component("src", DispatchableSource(pc), [
            VariableCost(:fuel, "output", energy, 1.0),
            FixedCapacity("output", energy, 48.0)
        ])
        dmd2 = Component("dmd2", Demand(pc, fill(1.0, 24)), [])
        dmd3 = Component("dmd3", Demand(pc, fill(1.0, 24)), [])
        connect!(s, src, n1)
        connect!(s, dmd2, n2)
        connect!(s, dmd3, n3)

       b12, b23, b31 = 1.5, 0.7, 2.0
        l12 = Component("l12", ACLine(pc, pc, b12), [
            FixedCapacity("from_out", energy, 100.0),  
            FixedCapacity("to_out", energy, 100.0),  
        ])
        l23 = Component("l23", ACLine(pc, pc, b23), [
            FixedCapacity("from_out", energy, 100.0),
            FixedCapacity("to_out", energy, 100.0),
        ])
        l31 = Component("l31", ACLine(pc, pc, b31), [
            FixedCapacity("from_out", energy, 100.0),
            FixedCapacity("to_out", energy, 100.0),
        ])

        connect!(s, l12, n1, "from_out"); connect!(s, l12, n1, "from_in")
        connect!(s, l12, n2, "to_in"); connect!(s, l12, n2, "to_out")

        connect!(s, l23, n2, "from_out"); connect!(s, l23, n2, "from_in")
        connect!(s, l23, n3, "to_in"); connect!(s, l23, n3, "to_out")

        connect!(s, l31, n3, "from_out"); connect!(s, l31, n3, "from_in")
        connect!(s, l31, n1, "to_in"); connect!(s, l31, n1, "to_out")

        optimize!(s, cost)
        @assert is_solved_and_feasible(sim.model)

        # KVL: sum( net_flow_ij / B_ij ) = 0  (net_flow = from->to - to->from)
        f12 = JuMP.value.(_transmissionbalance(s, "n1", "n2"))
        f23 = JuMP.value.(_transmissionbalance(s, "n2", "n3"))
        f31 = JuMP.value.(_transmissionbalance(s, "n3", "n1"))

        lhs = f12 ./ b12 .+ f23 ./ b23 .+ f31 ./ b31
        @test all(isapprox.(lhs, 0.0; atol=1e-6))

        # Antisymmetry check: reverse direction flow must have opposite sign
        f21 = JuMP.value.(_transmissionbalance(s, "n2", "n1"))
        @test all(isapprox.(f21, .-f12; atol=1e-6)) 

        # After optimization, the generator’s hourly output must equal the sum of demand time series (KCL check)    
        ex = Nosy.extract(s)
        src_hourly = balance(ex, "src", :output, energy; collapse=false, aggregate=true)
        dmd2_hourly = balance(ex, "dmd2", :input, energy; collapse=false, aggregate=true)
        dmd3_hourly = balance(ex, "dmd3", :input, energy; collapse=false, aggregate=true)
        @test all(isapprox.(src_hourly.data, dmd2_hourly.data .+ dmd3_hourly.data; atol=1e-6))
    end

    # mixed AC/DC mesh: verify KVL only considers AC lines in cycles, ignoring DC lines
    let
        sim = Sim(Model(HiGHS.Optimizer), mesh=TimeMesh(fill(1//1, 24)))
        set_silent(sim.model)
        pc = PowerCarrier("electricity", sim)
        s  = Snapshot(sim)

        n1 = Node("n1", pc, rule=:default)
        n2 = Node("n2", pc, rule=:default)
        n3 = Node("n3", pc, rule=:default)
        n4 = Node("n4", pc, rule=:default)

        src  = Component("src", DispatchableSource(pc), [
            VariableCost(:fuel, "output", energy, 1.0),
            FixedCapacity("output", energy, 100.0)
        ])
        dmd3 = Component("dmd3", Demand(pc, fill(1.0, 24)), [])
        dmd4 = Component("dmd4", Demand(pc, fill(1.0, 24)), [])
        connect!(s, src, n1)
        connect!(s, dmd3, n3)
        connect!(s, dmd4, n4)

        b12, b23, b31 = 1.5, 0.7, 2.0
        l12 = Component("l12", ACLine(pc, pc, b12), [])
        l23 = Component("l23", ACLine(pc, pc, b23), [])
        l31 = Component("l31", ACLine(pc, pc, b31), [])
        ldc = Component("ldc", DCLine(pc, pc), [])

        connect!(s, l12, n1, "from_out"); connect!(s, l12, n1, "from_in")
        connect!(s, l12, n2, "to_in"); connect!(s, l12, n2, "to_out")

        connect!(s, l23, n2, "from_out"); connect!(s, l23, n2, "from_in")
        connect!(s, l23, n3, "to_in"); connect!(s, l23, n3, "to_out")

        connect!(s, l31, n3, "from_out"); connect!(s, l31, n3, "from_in")
        connect!(s, l31, n1, "to_in"); connect!(s, l31, n1, "to_out")

        connect!(s, ldc, n2, "from_out"); connect!(s, ldc, n2, "from_in")
        connect!(s, ldc, n4, "to_in"); connect!(s, ldc, n4, "to_out")

        optimize!(s, cost)
        @assert is_solved_and_feasible(sim.model)

        # check KVL still holds for AC loop (n1-n2-n3)
        f12 = JuMP.value.(_transmissionbalance(s, "n1", "n2"))
        f23 = JuMP.value.(_transmissionbalance(s, "n2", "n3"))
        f31 = JuMP.value.(_transmissionbalance(s, "n3", "n1"))

        lhs = f12 ./ b12 .+ f23 ./ b23 .+ f31 ./ b31
        @test all(isapprox.(lhs, 0.0; atol=1e-6))

        # After optimization, the generator’s hourly output must equal the sum of demand time series (KCL check)    
        ex = Nosy.extract(s)
        src_hourly = balance(ex, "src", :output, energy; collapse=false, aggregate=true)
        dmd3_hourly = balance(ex, "dmd3", :input, energy; collapse=false, aggregate=true)
        dmd4_hourly = balance(ex, "dmd4", :input, energy; collapse=false, aggregate=true)
        @test all(isapprox.(src_hourly.data, dmd3_hourly.data .+ dmd4_hourly.data; atol=1e-6))

    end

end
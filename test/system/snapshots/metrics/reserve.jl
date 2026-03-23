using Nosy: Sim, TimeMesh
using Nosy: EnergyCarrier, Node
using Nosy: DispatchableSource, BasicStorage
using Nosy: Component, Snapshot, connect!, getcomponent, tag!
using Nosy: FixedCapacity, Ramping, ReserveUp, ReserveDown, UnitCommitment
using Nosy: reserve, energy
using JuMP: Model
using Test

@testset "Snapshot reserve" begin

    tsim() = Sim(Model(), mesh=TimeMesh(fill(1//2, 4)))
    reserve_name = "test"  # example reserve name for grouping

    function makesnapshot(vb)
        s = tsim()
        ec = EnergyCarrier("e", s)
        c = Component("comp", DispatchableSource(ec), vb)
        n = Node("node", ec)
        sn = Snapshot(s)
        connect!(sn, c, n)
        return sn
    end

    # single component: snapshot reserve equals component reserve
    let s = makesnapshot([
            FixedCapacity("output", energy, 10.0),
            Ramping("output", :up, 6.0; modifier=energy),
            ReserveUp(reserve_name, "output", :up, 1.0; modifier=energy),
        ])

        @test reserve(s, :up, reserve_name) == reserve(getcomponent(s, "comp"), :up, reserve_name)
        @test reserve(s, :down, reserve_name) == reserve(getcomponent(s, "comp"), :down, reserve_name)
        @test reserve(s, "comp", :up, reserve_name) == reserve(getcomponent(s, "comp"), :up, reserve_name)
        @test reserve(s, "comp", :down, reserve_name) == reserve(getcomponent(s, "comp"), :down, reserve_name)

    end

    # no ReserveUp behavior: reserve is zero
    let s = makesnapshot([FixedCapacity("output", energy, 10.0)])

        @test all(iszero.(reserve(s, :up, reserve_name).data))
        @test all(iszero.(reserve(s, :down, reserve_name).data))

    end
    
    function makesnapshot2(vb)
        s = tsim()
        ec = EnergyCarrier("e", s)
        c1 = Component("comp1", DispatchableSource(ec), vb)
        c2 = Component("comp2", DispatchableSource(ec), vb)
        n1 = Node("node1", ec)
        n2 = Node("node2", ec)
        sn = Snapshot(s)
        connect!(sn, c1, n1)
        connect!(sn, c2, n2)
        return sn
    end

    # multiple components: snapshot reserve equals sum of component reserves
    let s = makesnapshot2([
            FixedCapacity("output", energy, 10.0),
            Ramping("output", :up, 6.0; modifier=energy),
            ReserveUp(reserve_name, "output", :up, 1.0; modifier=energy),
        ])

        @test reserve(s, :up, reserve_name) == reserve(getcomponent(s, "comp1"), :up, reserve_name) + reserve(getcomponent(s, "comp2"), :up, reserve_name)
        @test reserve(s, :down, reserve_name) == reserve(getcomponent(s, "comp1"), :down, reserve_name) + reserve(getcomponent(s, "comp2"), :down, reserve_name)

    end


    # ReserveUp with UnitCommitment: snapshot reserve equals component reserve
    let s = makesnapshot([
            FixedCapacity("output", energy, 10.0, unitsize=5.0),
            UnitCommitment("output", 0.5, startup=0, shutdown=0, uptime=0, downtime=0, integer=false),
            ReserveUp(reserve_name, "output", :up, 1.0; modifier=energy),
        ])

        @test reserve(s, :up, reserve_name) == reserve(getcomponent(s, "comp"), :up, reserve_name)
        @test reserve(s, :down, reserve_name) == reserve(getcomponent(s, "comp"), :down, reserve_name)

    end


    # Node reserve: reserve equals sum of connected components
    let s = Sim(Model(), mesh=TimeMesh(fill(1//2, 4)))
        ec = EnergyCarrier("e", s)
        sn = Snapshot(s)
        n = Node("n", ec)
        
        c1 = Component("gen1", DispatchableSource(ec), [
            FixedCapacity("output", energy, 10.0),
            Ramping("output", :up, 6.0; modifier=energy),
            ReserveUp(reserve_name, "output", :up, 1.0; modifier=energy),
        ])
        connect!(sn, c1, n)
        
        c2 = Component("gen2", DispatchableSource(ec), [
            FixedCapacity("output", energy, 5.0),
            Ramping("output", :up, 100.0; modifier=energy),
            ReserveUp(reserve_name, "output", :up, 1.0; modifier=energy),
        ])
        connect!(sn, c2, n)
        
        node_reserve = reserve(sn, "n", :up, reserve_name)
        comp1_reserve = reserve(getcomponent(sn, "gen1"), :up, reserve_name)
        comp2_reserve = reserve(getcomponent(sn, "gen2"), :up, reserve_name)
        
        @test node_reserve == comp1_reserve + comp2_reserve
        @test all(iszero.(reserve(sn, "n", :down, reserve_name).data))
    end

    # Storage snapshot: reserve with duration limited storage
    let s = Sim(Model(), mesh=TimeMesh(fill(1//2, 4)))
        ec = EnergyCarrier("e", s)
        sn = Snapshot(s)
        n = Node("n", ec, rule=:curtailed)
        
        sto = Component("storage", BasicStorage(ec, eff_o=0.9), [
            FixedCapacity("output", energy, 10.0),
            FixedCapacity("input", energy, 5.0),
            FixedCapacity("level", energy, 100.0),
            ReserveUp("test2h", "output", :up, 2.0; modifier=energy),
        ])
        connect!(sn, sto, n)
        
        snap_reserve = reserve(sn, :up, "test2h")
        comp_reserve = reserve(getcomponent(sn, "storage"), :up, "test2h")
        
        @test snap_reserve == comp_reserve
        @test reserve(sn, "storage", :up, "test2h") == comp_reserve
        @test all(iszero.(reserve(sn, :down, "test2h").data))
    end

    # single component with ReserveDown: snapshot reserve equals component reserve
    let s = makesnapshot([
            FixedCapacity("output", energy, 10.0),
            Ramping("output", :down, 6.0; modifier=energy),
            ReserveDown(reserve_name, "output", :down, 1.0; modifier=energy),
        ])

        @test reserve(s, :up, reserve_name) == reserve(getcomponent(s, "comp"), :up, reserve_name)
        @test reserve(s, :down, reserve_name) == reserve(getcomponent(s, "comp"), :down, reserve_name)
    end

    # multiple components with ReserveDown: snapshot reserve equals sum of component reserves
    let s = makesnapshot2([
            FixedCapacity("output", energy, 10.0),
            Ramping("output", :down, 6.0; modifier=energy),
            ReserveDown(reserve_name, "output", :down, 1.0; modifier=energy),
        ])

        @test reserve(s, :up, reserve_name) == reserve(getcomponent(s, "comp1"), :up, reserve_name) + reserve(getcomponent(s, "comp2"), :up, reserve_name)
        @test reserve(s, :down, reserve_name) == reserve(getcomponent(s, "comp1"), :down, reserve_name) + reserve(getcomponent(s, "comp2"), :down, reserve_name)
    end

    # ReserveDown with UnitCommitment: snapshot reserve equals component reserve
    let s = makesnapshot([
            FixedCapacity("output", energy, 10.0, unitsize=5.0),
            UnitCommitment("output", 0.5, startup=0, shutdown=0, uptime=0, downtime=0, integer=false),
            ReserveDown(reserve_name, "output", :down, 1.0; modifier=energy),
        ])

        @test reserve(s, :up, reserve_name) == reserve(getcomponent(s, "comp"), :up, reserve_name)
        @test reserve(s, :down, reserve_name) == reserve(getcomponent(s, "comp"), :down, reserve_name)
    end

    # Node reserve with ReserveDown: reserve equals sum of connected components
    let s = Sim(Model(), mesh=TimeMesh(fill(1//2, 4)))
        ec = EnergyCarrier("e", s)
        sn = Snapshot(s)
        n = Node("n", ec)
        
        c1 = Component("gen1", DispatchableSource(ec), [
            FixedCapacity("output", energy, 10.0),
            Ramping("output", :down, 6.0; modifier=energy),
            ReserveDown(reserve_name, "output", :down, 1.0; modifier=energy),
        ])
        connect!(sn, c1, n)
        
        c2 = Component("gen2", DispatchableSource(ec), [
            FixedCapacity("output", energy, 5.0),
            Ramping("output", :down, 100.0; modifier=energy),
            ReserveDown(reserve_name, "output", :down, 1.0; modifier=energy),
        ])
        connect!(sn, c2, n)
        
        node_reserve = reserve(sn, "n", :down, reserve_name)
        comp1_reserve = reserve(getcomponent(sn, "gen1"), :down, reserve_name)
        comp2_reserve = reserve(getcomponent(sn, "gen2"), :down, reserve_name)
        
        @test node_reserve == comp1_reserve + comp2_reserve
        @test all(iszero.(reserve(sn, "n", :up, reserve_name).data))
    end

    # Tag support: reserve filtered by tags
    let s = Sim(Model(), mesh=TimeMesh(fill(1//2, 4)))
        ec = EnergyCarrier("e", s)
        sn = Snapshot(s)
        n = Node("n", ec)

        c1 = Component("gen1", DispatchableSource(ec), [
            FixedCapacity("output", energy, 10.0),
            Ramping("output", :up, 6.0; modifier=energy),
            ReserveUp(reserve_name, "output", :up, 1.0; modifier=energy),
        ])
        tag!(c1, :tagged)
        connect!(sn, c1, n)

        c2 = Component("gen2", DispatchableSource(ec), [
            FixedCapacity("output", energy, 5.0),
            Ramping("output", :up, 100.0; modifier=energy),
            ReserveUp(reserve_name, "output", :up, 1.0; modifier=energy),
        ])
        connect!(sn, c2, n)

        # All components
        total_reserve = reserve(sn, :up, reserve_name)
        comp1_reserve = reserve(getcomponent(sn, "gen1"), :up, reserve_name)
        comp2_reserve = reserve(getcomponent(sn, "gen2"), :up, reserve_name)
        @test total_reserve == comp1_reserve + comp2_reserve

        # Only tagged component
        tagged_reserve = reserve(sn, :up, reserve_name; with=[:tagged])
        @test tagged_reserve == comp1_reserve

        # Without tagged component
        untagged_reserve = reserve(sn, :up, reserve_name; without=[:tagged])
        @test untagged_reserve == comp2_reserve

        # Node reserve with tags
        node_tagged_reserve = reserve(sn, "n", :up, reserve_name; with=[:tagged])
        @test node_tagged_reserve == comp1_reserve

        node_untagged_reserve = reserve(sn, "n", :up, reserve_name; without=[:tagged])
        @test node_untagged_reserve == comp2_reserve
    end

end

using Nosy: Sim, TimeMesh
using Nosy: Stepwise
using Nosy: EnergyCarrier
using Nosy: DispatchableSource, BasicStorage
using Nosy: Component
using Nosy: FixedCapacity, Ramping, ReserveUp, ReserveDown, UnitCommitment
using Nosy: reserve, energy, getbehaviors, ReserveBehavior
using JuMP: Model
using Test

@testset "Component metric: reserve" begin

    tsim() = Sim(Model(), mesh=TimeMesh(fill(1//2, 4)))

    function makecomp(m, vbehavior)
        s = tsim()
        ec = EnergyCarrier("e", s)
        c = Component("c", m(ec), vbehavior)
        return c
    end

    # no ReserveUp behavior: reserve returns zero Stepwise
    let c = makecomp(DispatchableSource, [
            FixedCapacity("output", energy, 10.0),
        ])

        r_up = reserve(c, :up, "test")
        r_down = reserve(c, :down, "test")

        @test r_up isa Stepwise
        @test r_down isa Stepwise
        @test length(r_up.data) == 4
        @test length(r_down.data) == 4
        @test all(iszero.(r_up.data))
        @test all(iszero.(r_down.data))

    end

    # single ReserveUp behavior: reserve returns non zero up, zero down
    let c = makecomp(DispatchableSource, [
            FixedCapacity("output", energy, 10.0),
            Ramping("output", :up, 6.0; modifier=energy),
            ReserveUp("test", "output", :up, 1.0; modifier=energy),  # single reserve on output port
        ])

        r_up = reserve(c, :up, "test")
        r_down = reserve(c, :down, "test")

        @test all(iszero.(r_down.data))
        @test !all(iszero.(r_up.data))

    end

    # Storage reserve metric: discharge reserve
    let c = makecomp(BasicStorage, [
            FixedCapacity("output", energy, 4.0),
            FixedCapacity("input", energy, 3.0),
            FixedCapacity("level", energy, 100.0),
            Ramping("output", :up, 100.0; modifier=energy),
            ReserveUp("test", "output", :up, 2.0; modifier=energy),
        ])

        r_up = reserve(c, :up, "test")
        r_down = reserve(c, :down, "test")
        
        @test !all(iszero.(r_up.data))
        @test all(iszero.(r_down.data))

    end

    # Storage with both output (:up) and input (:down) reserves
    let c = makecomp(BasicStorage, [
            FixedCapacity("output", energy, 4.0),
            FixedCapacity("input", energy, 3.0),
            FixedCapacity("level", energy, 100.0),
            Ramping("output", :up, 100.0; modifier=energy),
            Ramping("input", :down, 50.0; modifier=energy),
            ReserveUp("test", "output", :up, 2.0; modifier=energy),
            ReserveUp("test", "input", :down, 2.0; modifier=energy),
        ])

        bs = [b for b in getbehaviors(c, ReserveBehavior) if b.rsense == :up]
        @test length(bs) == 2
        
        # Find behaviors by port and sense
        output_reserve = nothing
        input_reserve = nothing
        for b in bs
            if b.data.pname == "output" && b.data.sense == :up
                output_reserve = b
            elseif b.data.pname == "input" && b.data.sense == :down
                input_reserve = b
            end
        end
        
        @test !isnothing(output_reserve)
        @test !isnothing(input_reserve)
        
        r_up = reserve(c, :up, "test")
        r_down = reserve(c, :down, "test")
        
        # Reserve metric aggregates correctly
        @test r_up == output_reserve.r + input_reserve.r
        @test all(iszero.(r_down.data))

    end

    # ReserveUp with UnitCommitment: reserve metric aggregates correctly
    let c = makecomp(DispatchableSource, [
            FixedCapacity("output", energy, 15.0, unitsize=5.0),
            UnitCommitment("output", 0.4, startup=0, shutdown=0, uptime=0, downtime=0, integer=false),
            ReserveUp("test", "output", :up, 1.0; modifier=energy),
        ])

        r_up = reserve(c, :up, "test")
        @test !all(iszero.(r_up.data))
    end

    # single ReserveDown behavior: reserve returns non zero down, zero up
    let c = makecomp(DispatchableSource, [
            FixedCapacity("output", energy, 10.0),
            Ramping("output", :down, 6.0; modifier=energy),
            ReserveDown("test", "output", :down, 1.0; modifier=energy),  # single reserve on output port
        ])

        r_up = reserve(c, :up, "test")
        r_down = reserve(c, :down, "test")

        @test all(iszero.(r_up.data))
        @test !all(iszero.(r_down.data))
    end

    # Storage reserve metric: discharge reduction reserve
    let c = makecomp(BasicStorage, [
            FixedCapacity("output", energy, 4.0),
            FixedCapacity("input", energy, 3.0),
            FixedCapacity("level", energy, 100.0),
            Ramping("output", :down, 100.0; modifier=energy),
            ReserveDown("test", "output", :down, 2.0; modifier=energy),
        ])

        r_up = reserve(c, :up, "test")
        r_down = reserve(c, :down, "test")
        
        @test !all(iszero.(r_down.data))
        @test all(iszero.(r_up.data))
    end

    # ReserveDown with UnitCommitment: reserve metric aggregates correctly
    let c = makecomp(DispatchableSource, [
            FixedCapacity("output", energy, 15.0, unitsize=5.0),
            UnitCommitment("output", 0.4, startup=0, shutdown=0, uptime=0, downtime=0, integer=false),
            ReserveDown("test", "output", :down, 1.0; modifier=energy),
        ])

        r_down = reserve(c, :down, "test")
        @test !all(iszero.(r_down.data))
    end

end

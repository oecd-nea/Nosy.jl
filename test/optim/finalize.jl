using Nosy: mass, energy
using Nosy: Sim, TimeMesh, nvariables, nconstraints
using Nosy: DispatchableSource, BasicConverter, Demand
using Nosy: LinkedJointFlow
using Nosy: MassCarrier, EnergyCarrier
using Nosy: Component, Node, Snapshot, connect!
using Nosy: finalize!, is_finalized
using JuMP: Model
using Test

@testset "Snapshot finalization" begin

    tsim() = Sim(Model(), mesh=TimeMesh(fill(1//2, 10)))

    # # snapshot with one node and 2 components, no joint flows
    let s = tsim()
        
        snap = Snapshot(s)

        ec = EnergyCarrier("e", s)
        en = Node("energy", ec)

        mc = MassCarrier("m", s)
        mn = Node("mass", mc)

        disp = Component("disp", DispatchableSource(ec), [LinkedJointFlow("link", mc, :output, "output", x->x)])
        
        conv = Component("conv", BasicConverter(mc, ec), [])
      
        connect!(snap, conv, mn)
        connect!(snap, conv, en)
        connect!(snap, disp, en)

        # disp output port is connected, but the joint flow is not
        @test_throws AssertionError finalize!(snap)
        
        connect!(snap, disp, mn)

        # count variables and constraints before finalizing
        @test nvariables(s) == 10 + 10 # dispatchable source + converter flows
        @test nconstraints(s) == 10 + 10 # dispatchable source + converter flows lower bounds

        # snapshot not yet finalized (finalize! function not run yet)
        @test !is_finalized(snap)

        # all disp ports are now connected
        finalize!(snap)
        
        # snapshot is finalized (finalize! function was run)
        @test is_finalized(snap)

        # count variables and constraints after finalizing
        @test nvariables(s) == 10 + 10 # nothing has changed
        @test nconstraints(s) == 10 + 10 + 10 + 10 # node constraint at each timestep for each of the 2 nodes


        cons = Component("cons", Demand(ec, 10), [])

        # snapshot is already finalized: cannot connect component
        @test_throws AssertionError connect!(snap, cons, en)

    end


end

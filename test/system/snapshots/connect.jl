using Nosy: mass
using Nosy: Sim, TimeMesh
using Nosy: LinkedJointFlow
using Nosy: DispatchableSource, BasicConverter, Demand
using Nosy: MassCarrier, EnergyCarrier
using Nosy: mass, energy
using Nosy: Component, Node, portstructure, isfullyconnected, is_used, getport
using Nosy: hasinput, hasoutput, _input, _output
using Nosy: Snapshot, components, nodes, connect!, assertconnected
using JuMP: Model
using Test

@testset "Connect" begin

    tsim() = Sim(Model(), mesh=TimeMesh(fill(1//2, 10)))

    function makecomp(mc, ec, vbehavior=[])   
        d = BasicConverter(mc, ec)
        c = Component("comp", d, vbehavior)
        return c
    end    


    # base case: default connect, not all ports compatible
    let s = tsim()

        mc = MassCarrier("m", s, energy=[1,2,3,4,5])
        ec = EnergyCarrier("e", s)

        n = Node("n", mc)
        c = makecomp(mc, ec)
        sn = Snapshot(s)

        @test isempty(components(sn))
        @test isempty(nodes(sn))

        connect!(sn, c, n)

        @test length(components(sn)) == 1
        @test haskey(components(sn), "comp")

        @test length(nodes(sn)) == 1
        @test haskey(nodes(sn), "n")

        @test isempty(_input(portstructure(n)))
        @test length(_output(portstructure(n))) == 1
        @test hasoutput(n, "input", "comp")
        @test getport(n, "input", "comp") == getport(c, "input")

        @test is_used(getport(c, "input"))
        @test !is_used(getport(c, "output"))
        @test !isfullyconnected(c) # output was not connected

    end


    # all ports are compatible
    let s = tsim()

        mc = MassCarrier("m", s, energy=[1,2,3,4,5])

        n = Node("n", mc)
        c = makecomp(mc, mc) # same carrier in and out
        sn = Snapshot(s)
        connect!(sn, c, n)

        @test length(components(sn)) == 1
        @test haskey(components(sn), "comp")

        @test length(nodes(sn)) == 1
        @test haskey(nodes(sn), "n")

        @test length(_input(portstructure(n))) == 1
        @test hasinput(n, "output", "comp")
        @test getport(n, "input", "comp") == getport(c, "input")
        @test length(_output(portstructure(n))) == 1
        @test hasoutput(n, "input", "comp")
        @test getport(n, "output", "comp") == getport(c, "output")

        @test is_used(getport(c, "input"))
        @test is_used(getport(c, "output"))
        @test isfullyconnected(c) # both input and output were connected

    end


    # selective connect
    let s = tsim()

        mc = MassCarrier("m", s, energy=[1,2,3,4,5])

        n = Node("n", mc)
        c = makecomp(mc, mc) # same carrier in and out
        sn = Snapshot(s)
        connect!(sn, c, n, "input") # connecting input only

        @test length(components(sn)) == 1
        @test haskey(components(sn), "comp")

        @test length(nodes(sn)) == 1
        @test haskey(nodes(sn), "n")

        @test isempty(_input(portstructure(n)))
        @test length(_output(portstructure(n))) == 1
        @test hasoutput(n, "input", "comp")
        @test !hasinput(n, "output", "comp")
        @test getport(n, "input", "comp") == getport(c, "input")

        @test is_used(getport(c, "input"))
        @test !is_used(getport(c, "output"))
        @test !isfullyconnected(c) # output was not connected

    end


    # component with joint flow, only connect joint flow
    let s = tsim()

        mc = MassCarrier("m", s, energy=[1,2,3,4,5])
        ec = EnergyCarrier("e", s)

        j = LinkedJointFlow("j", ec, :output, "input", x->x[1])
        c = makecomp(mc, mc, [j]) # added joint flow (output)
        n = Node("n", ec) # node only compatible with joint flow
        sn = Snapshot(s)

        connect!(sn, c, n)

        @test length(components(sn)) == 1
        @test haskey(components(sn), "comp")

        @test length(nodes(sn)) == 1
        @test haskey(nodes(sn), "n")

        @test isempty(_output(portstructure(n)))
        @test length(_input(portstructure(n))) == 1
        @test hasinput(n, "j", "comp")
        @test getport(n, "j", "comp") == getport(c, "j")

        @test !is_used(getport(c, "input"))
        @test !is_used(getport(c, "output"))
        @test is_used(getport(c, "j"))
        @test !isfullyconnected(c) # input & output was not connected

    end


    # component with joint flow, but incompatible
    let s = tsim()

        mc = MassCarrier("m", s, energy=[1,2,3,4,5])
        ec = EnergyCarrier("e", s)

        j = LinkedJointFlow("j", ec, :output, "input", x->x[1])
        c = makecomp(mc, mc, [j]) # added joint flow (output)
        n = Node("n", mc) # node not compatible with joint flow
        sn = Snapshot(s)

        connect!(sn, c, n)

        @test length(components(sn)) == 1
        @test haskey(components(sn), "comp")

        @test length(nodes(sn)) == 1
        @test haskey(nodes(sn), "n")

        @test length(_output(portstructure(n))) == 1
        @test hasinput(n, "output", "comp")
        @test !hasinput(n, "j", "comp")

        @test is_used(getport(c, "input"))
        @test is_used(getport(c, "output"))
        @test !is_used(getport(c, "j"))
        @test !isfullyconnected(c) # joint flow was not connected

    end

    # no compatible port
    let s = tsim()

        mc = MassCarrier("m", s, energy=[1,2,3,4,5])
        ec = EnergyCarrier("e", s)

        n = Node("n", mc)
        c = makecomp(ec, ec) # no carrier in common between node and component
        sn = Snapshot(s)
        
        @test_throws AssertionError connect!(sn, c, n)
        
    end

    # node mesh must not be finer than connected port mesh
    let s = Sim(Model(), mesh=TimeMesh(fill(1//1, 4)))

        mc = MassCarrier("m", s)
        coarse = TimeMesh(fill(2//1, 2))

        n = Node("n", mc)
        c = Component("comp", DispatchableSource(mc; mesh=coarse))
        sn = Snapshot(s)

        @test_throws ArgumentError connect!(sn, c, n)
        @test !is_used(getport(c, "output"))

    end

    # component mesh may be finer than the simulation mesh when boundaries are aligned
    let s = Sim(Model(), mesh=TimeMesh(fill(2//1, 2)))

        ec = EnergyCarrier("e", s)
        fine = TimeMesh(fill(1//1, 4))

        n = Node("n", ec)
        c = Component("comp", DispatchableSource(ec; mesh=fine))
        sn = Snapshot(s)

        connect!(sn, c, n)

        @test is_used(getport(c, "output"))

    end


        # snapshot with one node and 2 components, no joint flows
        let s = tsim()
        
            snap = Snapshot(s)
    
            ec = EnergyCarrier("e", s)
            en = Node("energy", ec)
    
            mc = MassCarrier("m", s)
            mn = Node("mass", mc)
    
            disp = Component("disp", DispatchableSource(ec), [LinkedJointFlow("link", mc, :output, "output", x->x[1])])
            cons = Component("cons", Demand(ec, 10), [])
            conv = Component("conv", BasicConverter(mc, ec), [])
    
            # no component is connected, so "all" connected components are fully connected
            @test assertconnected(snap)
          
            connect!(snap, cons, en)
    
            # cons only has 1 port -> now fully connected. Other components are not connected at all
            @test assertconnected(snap)
    
            connect!(snap, conv, mn)
    
            # conv is partially connected: to mn, but not to en
            @test_throws AssertionError assertconnected(snap)
    
            connect!(snap, conv, en)
    
            # conv is now fully connected (mn, en)
            @test assertconnected(snap)
    
            connect!(snap, disp, en)
    
            # disp output port is connected, but the joint flow is not
            @test_throws AssertionError assertconnected(snap)
            
            connect!(snap, disp, mn)
    
            # all disp ports are now connected
            @test assertconnected(snap)
            
    
        end


end

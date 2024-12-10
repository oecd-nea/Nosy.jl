using POSY2: mass, energy
using POSY2: Sim, TimeMesh
using POSY2: VariableCapacity, FixedCapacity
using POSY2: BasicConverter
using POSY2: VariableCost, OvernightCost
using POSY2: overnightcost, variablecost, cost
using POSY2: MassCarrier, EnergyCarrier
using POSY2: Component, Node, Snapshot, connect!, getcomponent, balance, getport
using JuMP: Model, AffExpr
using ArgCheck: ArgumentError

@testset "Snapshot costs" begin

    tsim() = Sim(TimeMesh(fill(1//2, 10)), Model())

    # snapshot with one component
    function makeconv(s, vb, cname="comp")
        mc = MassCarrier("m", s, energy=[1,2,3,4,5])
        ec = EnergyCarrier("e", s)
        d = BasicConverter(
            mc,
            ec,
        )   
        c = Component(cname, d, vb)
        return c
    end

    function makesnapshot(vb)
        s = tsim()
        c = makeconv(s, vb)
        n = Node("mass node", c.model.data.input) # mass carrier node
        sn = Snapshot(s)
        connect!(sn, c, n)
        return sn
    end

    let s = makesnapshot([FixedCapacity("input", mass, 5.), OvernightCost(:overnight, "input", mass, 10.), VariableCost(:vom, "input", energy, 2.), VariableCost(:vom, "input", energy, 2.)])

        # fixed capacity + overnight cost
        @test overnightcost(s, "comp") == AffExpr(5. * 10.)

        @test variablecost(s, "comp") == balance(getcomponent(s, "comp"), :input, energy, collapse=true, aggregate=true) * 2.

        @test cost(s, "comp") == AffExpr(5. * 10.) + balance(getcomponent(s, "comp"), :input, energy, collapse=true, aggregate=true) * 2.

        # Snapshot cost
        @test cost(s) == cost(s, "comp") # only component is c

    end


    let s = makesnapshot([FixedCapacity("input", mass, 5.), OvernightCost(:overnight, "input", mass, 10.), VariableCost(:fuel, "input", energy, 2.), VariableCost(:vom, "output", energy, 3.)])

        c = getcomponent(s, "comp")
        
        @test overnightcost(s, "comp", :overnight) == AffExpr(5. * 10.)
        @test overnightcost(s, "comp", :other) == 0.
        @test variablecost(s, "comp") == sum(energy(getport(c, "input"))) * 2 + sum(energy(getport(c, "output"))) * 3
        @test variablecost(s, "comp", :fuel) == sum(energy(getport(c, "input"))) * 2
        @test variablecost(s, "comp", :vom) == sum(energy(getport(c, "output"))) * 3
        @test cost(s, "comp") == AffExpr(5. * 10.) + sum(energy(getport(c, "input"))) * 2 + sum(energy(getport(c, "output"))) * 3
        @test cost(s, "comp", :overnight) == overnightcost(c, :overnight)
        @test cost(s, "comp", :fuel) == variablecost(c, :fuel)
        @test cost(s, "comp", :vom) == variablecost(c, :vom)
        @test cost(s, :overnight) == overnightcost(c, :overnight)
        @test cost(s, :fuel) == variablecost(c, :fuel)
        @test cost(s, :vom) == variablecost(c, :vom)


    end


    let s = makesnapshot([])

        # no overnight costs
        @test overnightcost(s, "comp") == 0.
        @test variablecost(s, "comp") == 0.
        @test cost(s, "comp") == 0.
        @test cost(s) == 0.

    end


    let s = makesnapshot([])

        # no component with name `nocomp`
        @test_throws AssertionError overnightcost(s, "nocomp")
        @test_throws AssertionError variablecost(s, "nocomp")
        @test_throws AssertionError cost(s, "nocomp")

    end


    # snapshot with 2 components
    function makesnapshot2(vb)
        s = tsim()
        c1 = makeconv(s, vb, "comp1")
        c2 = makeconv(s, vb, "comp2")
        n1 = Node("mass node 1", c1.model.data.input) # mass carrier node
        n2 = Node("mass node 2", c2.model.data.input) # mass carrier node
        sn = Snapshot(s)
        connect!(sn, c1, n1)
        connect!(sn, c2, n2)
        return sn
    end


    let s = makesnapshot2([FixedCapacity("input", mass, 5.), OvernightCost(:overnight, "input", mass, 10.), VariableCost(:fuel, "input", energy, 2.), VariableCost(:vom, "output", energy, 3.)])

        # check variable cost is non-zero
        @test (variablecost(s) isa AffExpr) && !iszero(variablecost(s))

        @test variablecost(s) == variablecost(s, "comp1") + variablecost(s, "comp2")

        @test variablecost(s, :fuel) == variablecost(s, "comp1", :fuel) + variablecost(s, "comp2", :fuel)

        # check overnight cost is non-zero
        @test (overnightcost(s) isa AffExpr) && !iszero(overnightcost(s))

        @test overnightcost(s) == overnightcost(s, "comp1") + overnightcost(s, "comp2")

        @test overnightcost(s, :overnight) == overnightcost(s, "comp1", :overnight) + overnightcost(s, "comp2", :overnight)

        # check cost is non-zero
        @test (cost(s) isa AffExpr) && !iszero(cost(s))

        @test cost(s) == cost(s, "comp1") + cost(s, "comp2")

        @test cost(s, :overnight) == cost(s, "comp1", :overnight) + cost(s, "comp2", :overnight)

        @test cost(s, :fuel) == cost(s, "comp1", :fuel) + cost(s, "comp2", :fuel)

    end

end
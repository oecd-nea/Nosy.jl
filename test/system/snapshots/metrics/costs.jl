using Nosy: mass, energy
using Nosy: Sim, TimeMesh
using Nosy: FixedCapacity, UnitCommitment
using Nosy: BasicConverter
using Nosy: VariableCost, FixedCost, NoLoadCost, StartupCost
using Nosy: fixedcost, variablecost, noloadcost, startupcost, cost
using Nosy: MassCarrier, EnergyCarrier
using Nosy: Component, Node, Snapshot, connect!, getcomponent, balance, getport
using JuMP: Model, GenericAffExpr, AffExpr
using Test

@testset "Snapshot costs" begin

    tsim() = Sim(Model(), mesh=TimeMesh(fill(1//2, 10)))

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

    let s = makesnapshot([FixedCapacity("input", mass, 5.), FixedCost(:overnight, "input", mass, 10.), VariableCost(:vom, "input", energy, 2.), VariableCost(:vom, "input", energy, 2.)])

        # fixed capacity + fixed cost
        @test fixedcost(s, "comp") == AffExpr(5. * 10.)

        @test variablecost(s, "comp") == balance(getcomponent(s, "comp"), :input, energy, collapse=true, aggregate=true) * 2.

        @test cost(s, "comp") == AffExpr(5. * 10.) + balance(getcomponent(s, "comp"), :input, energy, collapse=true, aggregate=true) * 2.

        # Snapshot cost
        @test cost(s) == cost(s, "comp") # only component is c

    end


    let s = makesnapshot([
        FixedCapacity("input", mass, 5., unitsize=1.), 
        UnitCommitment("input", 0.5),
        FixedCost(:overnight, "input", mass, 10.), 
        VariableCost(:fuel, "input", energy, 2.), 
        VariableCost(:vom, "output", energy, 3.),
        NoLoadCost(:noload, "input", 2.),
        StartupCost(:startup, "input", 5.)
        ])

        c = getcomponent(s, "comp")
        
        @test fixedcost(s, "comp", :overnight) == AffExpr(5. * 10.)
        @test fixedcost(s, "comp", :other) == 0.
        @test variablecost(s, "comp") == sum(energy(getport(c, "input"))) * 2 + sum(energy(getport(c, "output"))) * 3
        @test variablecost(s, "comp", :fuel) == sum(energy(getport(c, "input"))) * 2
        @test variablecost(s, "comp", :vom) == sum(energy(getport(c, "output"))) * 3
        # noload cost tested separately, in behavior tests
        # startup cost tested separately, in behaviors tests
        @test cost(s, "comp") == AffExpr(5. * 10.) + sum(energy(getport(c, "input"))) * 2 + sum(energy(getport(c, "output"))) * 3 + noloadcost(s, "comp") + startupcost(s, "comp")
        @test cost(s, "comp", :overnight) == fixedcost(c, :overnight)
        @test cost(s, "comp", :fuel) == variablecost(c, :fuel)
        @test cost(s, "comp", :vom) == variablecost(c, :vom)
        @test cost(s, "comp", :noload) == noloadcost(c, :noload)
        @test cost(s, "comp", :startup) == startupcost(c, :startup)
        @test cost(s, :overnight) == fixedcost(c, :overnight)
        @test cost(s, :fuel) == variablecost(c, :fuel)
        @test cost(s, :vom) == variablecost(c, :vom)
        @test cost(s, :noload) == noloadcost(c, :noload)
        @test cost(s, :startup) == startupcost(c, :startup)

    end


    let s = makesnapshot([])

        # no fixed costs
        @test fixedcost(s, "comp") == 0.
        @test variablecost(s, "comp") == 0.
        @test cost(s, "comp") == 0.
        @test cost(s) == 0.

    end


    let s = makesnapshot([])

        # no component with name `nocomp`
        @test_throws AssertionError fixedcost(s, "nocomp")
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


    let s = makesnapshot2([
        FixedCapacity("input", mass, 5., unitsize=1), 
        UnitCommitment("input", 0.5),
        FixedCost(:overnight, "input", mass, 10.), 
        VariableCost(:fuel, "input", energy, 2.), 
        VariableCost(:vom, "output", energy, 3.),
        NoLoadCost(:noload, "input", 2.),
        StartupCost(:startup, "input", 5.)
    ])
        # check variable cost is non-zero
        @test (variablecost(s) isa GenericAffExpr) && !iszero(variablecost(s))

        @test variablecost(s) == variablecost(s, "comp1") + variablecost(s, "comp2")

        @test variablecost(s, :fuel) == variablecost(s, "comp1", :fuel) + variablecost(s, "comp2", :fuel)

        # check fixed cost is non-zero
        @test (fixedcost(s) isa GenericAffExpr) && !iszero(fixedcost(s))

        @test fixedcost(s) == fixedcost(s, "comp1") + fixedcost(s, "comp2")

        @test fixedcost(s, :overnight) == fixedcost(s, "comp1", :overnight) + fixedcost(s, "comp2", :overnight)

        # check no-load cost is non-zero
        @test (noloadcost(s) isa GenericAffExpr) && !iszero(noloadcost(s))

        @test noloadcost(s) == noloadcost(s, "comp1") + noloadcost(s, "comp2")

        @test noloadcost(s, :noload) == noloadcost(s, "comp1", :noload) + noloadcost(s, "comp2", :noload)

        # check startup cost is non-zero
        @test (startupcost(s) isa GenericAffExpr) && !iszero(startupcost(s))

        @test startupcost(s) == startupcost(s, "comp1") + startupcost(s, "comp2")

        @test startupcost(s, :startup) == startupcost(s, "comp1", :startup) + startupcost(s, "comp2", :startup)    

        # check cost is non-zero
        @test (cost(s) isa GenericAffExpr) && !iszero(cost(s))

        @test cost(s) == cost(s, "comp1") + cost(s, "comp2")

        @test cost(s, :overnight) == cost(s, "comp1", :overnight) + cost(s, "comp2", :overnight)

        @test cost(s, :fuel) == cost(s, "comp1", :fuel) + cost(s, "comp2", :fuel)

        @test cost(s, :noload) == cost(s, "comp1", :noload) + cost(s, "comp2", :noload)

    end

end

using Nosy: mass, energy
using Nosy: Sim, TimeMesh
using Nosy: BasicConverter
using Nosy: Demand
using Nosy: VariableCost, VariableCostBehavior
using Nosy: variablecost, _variablecost
using Nosy: build, _sortbehaviordata
using Nosy: MassCarrier, EnergyCarrier
using Nosy: Component, balance
using JuMP: Model, AffExpr
using ArgCheck: ArgumentError
using Test

@testset "VariableCost" begin

    tsim() = Sim(Model(), mesh=TimeMesh(fill(1//2, 10)))

    function makeconv(vb)
        s = tsim()    
        mc = MassCarrier("m", s, energy=[1,2,3,4,5])
        ec = EnergyCarrier("e", s)
        d = BasicConverter(
            mc,
            ec,
        )   
        c = Component("comp", d, vb)
        return c
    end

    function makefixeddemand(flow, cost; style=:step, circular=true)
        s = Sim(Model(), mesh=TimeMesh([1//2, 1//1, 3//2]; circular=circular))
        ec = EnergyCarrier("e", s)
        return Component("load", Demand(ec, flow), [
            VariableCost(:vom, "input", energy, cost; style=style),
        ])
    end

    function nextindex(t, weights; circular=true)
        if t < length(weights)
            return t + 1
        end
        return circular ? 1 : t
    end

    function intervalindices(weights; circular=true)
        if circular
            return eachindex(weights)
        end
        return firstindex(weights):(lastindex(weights)-1)
    end

    function expected_step_cost(flow, cost, weights; circular=true)
        total = 0.0
        for t in intervalindices(weights; circular=circular)
            next = nextindex(t, weights; circular=circular)
            total += Float64(weights[t]) * cost[t] * (flow[t] + flow[next]) / 2
        end
        return total
    end

    function expected_scalar_cost(flow, cost, weights; circular=true)
        total = 0.0
        for t in intervalindices(weights; circular=circular)
            next = nextindex(t, weights; circular=circular)
            total += Float64(weights[t]) * cost * (flow[t] + flow[next]) / 2
        end
        return total
    end

    function expected_linear_cost(flow, cost, weights; circular=true)
        total = 0.0
        for t in intervalindices(weights; circular=circular)
            next = nextindex(t, weights; circular=circular)
            interval_average =
                flow[t] * cost[t] / 3 +
                flow[t] * cost[next] / 6 +
                flow[next] * cost[t] / 6 +
                flow[next] * cost[next] / 3
            total += Float64(weights[t]) * interval_average
        end
        return total
    end

    # scalar variable cost
    let c = makeconv([VariableCost(:vom, "input", mass, 10)])

        @test c.behaviors[1] isa VariableCostBehavior{AffExpr}

        # adapting to fixed capacity
        @test _variablecost(c.behaviors[1]) == 10 * balance(c, :input, mass, collapse=true, aggregate=true)

        # component metric
        @test variablecost(c) == _variablecost(c.behaviors[1])

    end

    # vectorial variable cost - stepwise format
    let c = makeconv([VariableCost(:vom, "input", mass, fill(10,10))])

        # adapting to variable capacity
        @test isapprox(_variablecost(c.behaviors[1]), 10 * balance(c, :input, mass, collapse=true, aggregate=true))

        # component metric
        @test variablecost(c) == _variablecost(c.behaviors[1])

    end


    # vectorial variable cost - hourly format
    let c = makeconv([VariableCost(:vom, "input", mass, fill(10,5))])

        # adapting to variable capacity
        @test isapprox(_variablecost(c.behaviors[1]), 10 * balance(c, :input, mass, collapse=true, aggregate=true))


        # component metric
        @test isapprox(variablecost(c), 10 * balance(c, :input, mass, collapse=true, aggregate=true))


    end


    # vectorial variable cost - wrong format
    @test_throws ArgumentError makeconv([VariableCost(:vom, "input", mass, fill(10,7))])

    # scalar variable cost - non-circular mesh only integrates intervals with both endpoints
    let flow = [1.0, 2.0, 4.0],
        cost = 10.0,
        weights = [1//2, 1//1, 3//2],
        c = makefixeddemand(flow, cost; circular=false)

        @test isapprox(_variablecost(c.behaviors[1]).constant, expected_scalar_cost(flow, cost, weights; circular=false))

    end

    # vectorial variable cost - non-uniform mesh step integration
    let flow = [1.0, 1.0, 1.0],
        cost = [10.0, 20.0, 50.0],
        weights = [1//2, 1//1, 3//2],
        c = makefixeddemand(flow, cost; style=:step)

        @test isapprox(_variablecost(c.behaviors[1]).constant, expected_step_cost(flow, cost, weights))

    end

    # vectorial variable cost - non-circular mesh step integration only uses known intervals
    let flow = [1.0, 1.0, 1.0],
        cost = [10.0, 20.0, 50.0],
        weights = [1//2, 1//1, 3//2],
        c = makefixeddemand(flow, cost; style=:step, circular=false)

        @test isapprox(_variablecost(c.behaviors[1]).constant, expected_step_cost(flow, cost, weights; circular=false))

    end

    # vectorial variable cost - non-uniform mesh linear integration
    let flow = [1.0, 2.0, 4.0],
        cost = [10.0, 20.0, 50.0],
        weights = [1//2, 1//1, 3//2],
        c = makefixeddemand(flow, cost; style=:linear)

        @test isapprox(_variablecost(c.behaviors[1]).constant, expected_linear_cost(flow, cost, weights))

    end

    # vectorial variable cost - non-circular mesh linear integration only uses known intervals
    let flow = [1.0, 2.0, 4.0],
        cost = [10.0, 20.0, 50.0],
        weights = [1//2, 1//1, 3//2],
        c = makefixeddemand(flow, cost; style=:linear, circular=false)

        @test isapprox(_variablecost(c.behaviors[1]).constant, expected_linear_cost(flow, cost, weights; circular=false))

    end

    # multiple variable costs
    let c = makeconv([VariableCost(:vom, "input", mass, 1), VariableCost(:fuel, "input", energy, 1)])

        @test length(c.behaviors) == 2
        @test variablecost(c) == _variablecost(c.behaviors[1]) + _variablecost(c.behaviors[2])

    end

    # non-identical variable costs must not be deduplicated by behavior sorting
    let c = makeconv([VariableCost(:vom, "input", mass, 1), VariableCost(:vom, "input", mass, 2)])

        @test length(c.behaviors) == 2
        @test variablecost(c) == 3 * balance(c, :input, mass, collapse=true, aggregate=true)

    end

    let s = tsim()
        mc = MassCarrier("m", s)
        ec = EnergyCarrier("e", s)
        m = build(BasicConverter(mc, ec), "comp")
        v = [VariableCost(:vom, "input", mass, 1), VariableCost(:vom, "input", mass, 1)]

        @test length(_sortbehaviordata(v, m)) == 2

    end

    # identical variable costs are ambiguous and rejected at construction
    @test_throws ArgumentError makeconv([VariableCost(:vom, "input", mass, 1), VariableCost(:vom, "input", mass, 1)])

    # no variable costs
    let c = makeconv([])

        @test variablecost(c) == 0. # Float64 (reduce memory allocation)

    end

end

using Nosy: Sim, TimeMesh, Model
using Nosy: EnergyCarrier
using Nosy: DispatchableSource, Demand
using Nosy: VariableCapacity, FixedCost, VariableCost
using Nosy: Component, Node, Snapshot, connect!, optimize!
using Nosy: LinkedJointFlow
using Nosy: cost, capacity, balance, dualprice, energy
using Nosy: extract, exportsnapshot, importsnapshot
using Nosy: getcomponent, getnode, model, sim

using HiGHS: Optimizer
using JuMP: set_silent
using Serialization: deserialize
using Test

module SnapshotIOClosurePayload

struct ExternalOption
    payload::Vector{Float64}
end

function linked(payload)
    return x -> x[1] * payload[1]
end

end

function _contains_bytes(path::AbstractString, needle::AbstractString)
    bytes = read(path)
    pattern = collect(codeunits(needle))
    return !isnothing(findfirst(pattern, bytes))
end

@testset "Snapshot I/O" begin

    tsim() = Sim(Model(Optimizer), mesh=TimeMesh(fill(1//2, 10)))

    let payload = ones(10)
        options = Dict{Symbol,Any}(
            :keep_number => 1.0,
            :keep_vector => [1.0, 2.0],
            :drop_external => SnapshotIOClosurePayload.ExternalOption(payload),
        )
        original = Nosy._exportsnapshot_sanitize_options!(options)

        @test options == Dict{Symbol,Any}(:keep_number => 1.0, :keep_vector => Any[1.0, 2.0])

        Nosy._exportsnapshot_restore_options!(options, original)
        @test options[:drop_external] isa SnapshotIOClosurePayload.ExternalOption
    end

    let s = tsim()
        set_silent(s.model)

        snap = Snapshot(s)
        ec = EnergyCarrier("e", s)
        en = Node("energy", ec)
        disp = Component("disp", DispatchableSource(ec), [VariableCapacity("output", energy), FixedCost(:overnight, "output", energy, 2.)])
        cons = Component("cons", Demand(ec, 10), [])

        connect!(snap, cons, en)
        connect!(snap, disp, en)

        @test_throws ArgumentError exportsnapshot(IOBuffer(), snap)

        optimize!(snap, cost(snap))
        extracted = extract(snap)

        path = tempname()
        exportpath = string(path, ".snap")
        try
            exportsnapshot(path, extracted)

            @test !isfile(path)
            @test isfile(exportpath)
            @test sim(extracted).model !== nothing

            raw = open(deserialize, exportpath, "r")
            @test raw isa Snapshot{Float64}
            @test sim(raw).model === nothing

            loaded = importsnapshot(exportpath)
            @test loaded isa Snapshot{Float64}
            @test sim(loaded).model === nothing
            @test sim(getcomponent(loaded, "disp")).model === nothing
            @test sim(getnode(loaded, "energy")).model === nothing
            @test_throws ArgumentError model(sim(loaded))

            @test isapprox(cost(loaded), 20.)
            @test isapprox(capacity(loaded, "disp"), 10.)
            @test isapprox(balance(loaded, "energy", :input, energy, collapse=true, aggregate=true), 50.)
            @test isnothing(dualprice(getnode(loaded, "energy")))
        finally
            isfile(path) && rm(path)
            isfile(exportpath) && rm(exportpath)
        end

        badpath = string(tempname(), ".bin")
        err = try
            exportsnapshot(badpath, extracted)
            nothing
        catch e
            e
        end
        @test err isa ArgumentError
        @test occursin(".snap", sprint(showerror, err))
        @test !isfile(badpath)
    end

    let s = tsim()
        set_silent(s.model)

        snap = Snapshot(s)
        ec = EnergyCarrier("e", s)
        en = Node("energy", ec, evalprice=true)
        disp = Component("disp", DispatchableSource(ec), [
            VariableCapacity("output", energy),
            FixedCost(:overnight, "output", energy, 2.),
            VariableCost(:fuel, "output", energy, 1.),
        ])
        cons = Component("cons", Demand(ec, 10), [])

        connect!(snap, cons, en)
        connect!(snap, disp, en)
        optimize!(snap, cost(snap))

        path = string(tempname(), ".snap")
        try
            exportsnapshot(path, extract(snap))
            loaded = importsnapshot(path)
            price = dualprice(getnode(loaded, "energy"))

            @test price !== nothing
            @test all(isapprox.(price, [2.5, 0.5, 0.5, 0.5, 0.5]))
        finally
            isfile(path) && rm(path)
        end
    end

    let s = tsim()
        set_silent(s.model)

        snap = Snapshot(s)
        ec = EnergyCarrier("e", s)
        en = Node("energy", ec)
        payload = zeros(250_000)
        disp = Component("disp", DispatchableSource(ec), [
            LinkedJointFlow("captured", ec, :output, "output", SnapshotIOClosurePayload.linked(payload)),
            VariableCapacity("output", energy),
            FixedCost(:overnight, "output", energy, 2.),
        ])
        cons = Component("cons", Demand(ec, 10), [])

        connect!(snap, cons, en)
        connect!(snap, disp, en)
        optimize!(snap, cost(snap))
        extracted = extract(snap)

        path = string(tempname(), ".snap")
        try
            @test occursin("SnapshotIOClosurePayload", string(typeof(getcomponent(extracted, "disp").jointflows[1].data.f)))
            exportsnapshot(path, extracted)

            @test filesize(path) < 1_000_000
            @test !_contains_bytes(path, "SnapshotIOClosurePayload")
            @test occursin("SnapshotIOClosurePayload", string(typeof(getcomponent(extracted, "disp").jointflows[1].data.f)))

            loaded = importsnapshot(path)
            @test loaded isa Snapshot{Float64}
            @test cost(loaded) ≈ 20.
        finally
            isfile(path) && rm(path)
        end
    end

end

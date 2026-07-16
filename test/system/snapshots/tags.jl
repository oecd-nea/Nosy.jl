using Nosy: Sim, TimeMesh
using Nosy: DispatchableSource
using Nosy: MassCarrier
using Nosy: Component, Node
using Nosy: Snapshot
using Nosy: tag!, hastag, getcomponents, getnodes, connect!
using JuMP: Model
using Test

@testset "Tags" begin

    tsim() = Sim(Model(), mesh=TimeMesh())

    function makecomp(cname, mc)
        d = DispatchableSource(mc)
        c = Component(cname, d)
        return c
    end

    let s = tsim(), mc = MassCarrier("m", s)

        snap = Snapshot(s)
        
        n = Node("n", mc)
        tag!(n, :n)

        c1 = makecomp("c1", mc)
        tag!(c1, :function, "onlyc1")
        tag!(c1, :group, "c1andc2")
        connect!(snap, c1, n)

        c2 = makecomp("c2", mc)
        tag!(c2, :group, "c1andc2")
        tag!(c2, :function, "onlyc2")
        connect!(snap, c2, n)

        c3 = makecomp("c3", mc)
        tag!(c3, :function, "onlyc3")
        connect!(snap, c3, n)


        # test getcomponents with key-value tags on snapshot level

        @test length(getcomponents(snap, "n", with=[:function => "onlyc1"], without=Pair{Symbol,String}[])) == 1 && haskey(getcomponents(snap, "n", with=[:function => "onlyc1"], without=Pair{Symbol,String}[]), "c1") && getcomponents(snap, "n", with=[:function => "onlyc1"], without=Pair{Symbol,String}[])["c1"] == c1

        @test length(getcomponents(snap, "n", with=[:group => "c1andc2"], without=Pair{Symbol,String}[])) == 2
        @test haskey(getcomponents(snap, "n", with=[:group => "c1andc2"], without=Pair{Symbol,String}[]), "c1") && getcomponents(snap, "n", with=[:group => "c1andc2"], without=Pair{Symbol,String}[])["c1"] == c1
        @test haskey(getcomponents(snap, "n", with=[:group => "c1andc2"], without=Pair{Symbol,String}[]), "c2") && getcomponents(snap, "n", with=[:group => "c1andc2"], without=Pair{Symbol,String}[])["c2"] == c2

        @test length(getcomponents(snap, "n", with=[:group => "c1andc2"], without=[:function => "onlyc1"])) == 1 && getcomponents(snap, "n", with=[:group => "c1andc2"], without=[:function => "onlyc1"])["c2"] == c2

        @test length(getcomponents(snap, "n", with=Pair{Symbol,String}[], without=[:group => "c1andc2"])) == 1 && getcomponents(snap, "n", with=Pair{Symbol,String}[], without=[:group => "c1andc2"])["c3"] == c3

        @test length(getcomponents(snap, "n", with=[:function => "none"], without=Pair{Symbol,String}[])) == 0

        @test length(getcomponents(snap, "n", with=Pair{Symbol,String}[], without=[:function => "none"])) == 3
        @test haskey(getcomponents(snap, "n", with=Pair{Symbol,String}[], without=[:function => "none"]), "c1") && getcomponents(snap, "n", with=Pair{Symbol,String}[], without=[:function => "none"])["c1"] == c1
        @test haskey(getcomponents(snap, "n", with=Pair{Symbol,String}[], without=[:function => "none"]), "c2") && getcomponents(snap, "n", with=Pair{Symbol,String}[], without=[:function => "none"])["c2"] == c2
        @test haskey(getcomponents(snap, "n", with=Pair{Symbol,String}[], without=[:function => "none"]), "c3") && getcomponents(snap, "n", with=Pair{Symbol,String}[], without=[:function => "none"])["c3"] == c3


        # nodes use Vector{Symbol} tags

        @test length(getnodes(snap, with=[:n], without=Symbol[])) == 1 && haskey(getnodes(snap, with=[:n], without=Symbol[]), "n") && getnodes(snap, with=[:n], without=Symbol[])["n"] == n

        @test length(getnodes(snap, with=Symbol[], without=[:n])) == 0

    end

    # tag!: multiple values per key, duplicate values ignored
    let s = tsim(), mc = MassCarrier("m", s)
        c = makecomp("c", mc)

        @test !hastag(c, :function, "a")
        tag!(c, :function, "a")
        @test hastag(c, :function, "a")
        @test c.tags[:function] == ["a"]

        tag!(c, :function, "b")
        @test hastag(c, :function, "b")
        @test c.tags[:function] == ["a", "b"]

        tag!(c, :function, "a")
        @test c.tags[:function] == ["a", "b"]

        @test !hastag(c, :missing, "x")
        @test !hastag(c, :function, "missing")
    end

    # constructor tags: changing tags after Component(...) does not change component tags
    let s = tsim(), mc = MassCarrier("m", s)
        tags = Dict(:function => ["a"])
        c = Component("c", DispatchableSource(mc); tags=tags)
        push!(tags[:function], "b")
        tags[:other] = ["x"]
        @test c.tags[:function] == ["a"]
        @test !haskey(c.tags, :other)
    end
end

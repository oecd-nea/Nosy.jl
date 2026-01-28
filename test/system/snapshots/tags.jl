using Nosy: Sim, TimeMesh
using Nosy: DispatchableSource
using Nosy: MassCarrier
using Nosy: Component, Node
using Nosy: Snapshot
using Nosy: tag!, getcomponents, getnodes, connect!
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
        tag!(c1, :onlyc1)
        tag!(c1, :c1andc2)
        connect!(snap, c1, n)

        c2 = makecomp("c2", mc)
        tag!(c2, :c1andc2)
        tag!(c2, :onlyc2)
        connect!(snap, c2, n)

        c3 = makecomp("c3", mc)
        tag!(c2, :onlyc3)
        connect!(snap, c3, n)


        # test getcomponents with tags on snapshot level

        @test length(getcomponents(snap, "n", with=[:onlyc1], without=Symbol[])) == 1 && haskey(getcomponents(snap, "n", with=[:onlyc1], without=Symbol[]), "c1") && getcomponents(snap, "n", with=[:onlyc1], without=Symbol[])["c1"] == c1
        
        @test length(getcomponents(snap, "n", with=[:c1andc2], without=Symbol[])) == 2
        @test haskey(getcomponents(snap, "n", with=[:c1andc2], without=Symbol[]), "c1") && getcomponents(snap, "n", with=[:c1andc2], without=Symbol[])["c1"] == c1
        @test haskey(getcomponents(snap, "n", with=[:c1andc2], without=Symbol[]), "c2") && getcomponents(snap, "n", with=[:c1andc2], without=Symbol[])["c2"] == c2

        @test length(getcomponents(snap, "n", with=[:c1andc2], without=[:onlyc1])) == 1 && getcomponents(snap, "n", with=[:c1andc2], without=[:onlyc1])["c2"] == c2

        @test length(getcomponents(snap, "n", with=Symbol[], without=[:c1andc2])) == 1 && getcomponents(snap, "n", with=Symbol[], without=[:c1andc2])["c3"] == c3

        @test length(getcomponents(snap, "n", with=Symbol[:none], without=Symbol[])) == 0

        @test length(getcomponents(snap, "n", with=Symbol[], without=Symbol[:none])) == 3
        @test haskey(getcomponents(snap, "n", with=Symbol[], without=Symbol[:none]), "c1") && getcomponents(snap, "n", with=Symbol[], without=Symbol[:none])["c1"] == c1
        @test haskey(getcomponents(snap, "n", with=Symbol[], without=Symbol[:none]), "c2") && getcomponents(snap, "n", with=Symbol[], without=Symbol[:none])["c2"] == c2
        @test haskey(getcomponents(snap, "n", with=Symbol[], without=Symbol[:none]), "c3") && getcomponents(snap, "n", with=Symbol[], without=Symbol[:none])["c3"] == c3
    

        # nodes use the same tagging mechanism, making tests smaller

        @test length(getnodes(snap, with=[:n], without=Symbol[])) == 1 && haskey(getnodes(snap, with=[:n], without=Symbol[]), "n") && getnodes(snap, with=[:n], without=Symbol[])["n"] == n

        @test length(getnodes(snap, with=Symbol[], without=[:n])) == 0

    end

end

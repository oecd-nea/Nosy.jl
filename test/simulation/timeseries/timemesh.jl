using Nosy: GenericTimeSeries, TimeMesh, RTimeMesh, Sim, Hourly, Stepwise
using Nosy: nhours, nsteps, weight, hour, step, eachhour, eachstep, iscircular
using JuMP: Model
using Test

@testset "Time series mesh" begin

    let
        
        # forbidden cases

        @test_throws ArgumentError TimeMesh(Int[]) # empty mesh is not meaningful

        @test_throws ArgumentError TimeMesh([1//2, 1//1]) # sum of weights is not integer

        @test_throws ArgumentError TimeMesh([1//1, 0//1]) # zero-duration timestep is not allowed

        @test_throws ArgumentError TimeMesh([1.0]) # weights must be exact integers or rationals

    end


    let

        # GenericTimeSeries is not mesh-backed, so Base helpers must preserve
        # only its own storage and circularity.
        s = GenericTimeSeries([1, 2, 3], false)

        c = copy(s)
        @test c isa GenericTimeSeries{Int}
        @test c !== s
        @test parent(c) == parent(s)
        @test parent(c) !== parent(s)
        @test !iscircular(c)

        z = zero(s)
        @test z isa GenericTimeSeries{Int}
        @test parent(z) == [0, 0, 0]
        @test !iscircular(z)

        t = similar(s)
        @test t isa GenericTimeSeries{Int}
        @test length(t) == length(s)
        @test !iscircular(t)

    end


    let

        # TimeMesh where all timesteps are 1 hour
        function genmesh_integer()
            w = fill(1, 8760)
            m = TimeMesh(w)
            return m
        end

        m = genmesh_integer()
        @test nhours(m) == 8760
        @test nsteps(m) == 8760
        @test all(weight(m, s) == 1 for s in 1:8760)
        @test all(hour(m, s) == s for s in 1:8760)
        @test all(step(m, h-1) == h for h in 1:8760)
        @test eachhour(m) == 1:8760
        @test eachstep(m) == 1:8760
        @test iscircular(m)
        @test m isa RTimeMesh
    
    end


    let

        # Integer weights are normalized to the canonical rational mesh type
        # used by simulations and mesh-backed time series.
        m = TimeMesh(fill(1, 4))
        s = Sim(Model(); mesh=m)
        h = Hourly(Float64.(1:4), m)
        st = Stepwise(Float64.(1:4), m)

        @test s.mesh === m
        @test h.mesh === m
        @test st.mesh === m
        @test all(weight(m, i) == 1//1 for i in 1:4)

    end


    let

        # TimeMesh where all timesteps are 1/2 hour
        function genmesh_rational1()
            w = fill(1//2, 8760*2)
            m = TimeMesh(w)
            return m
        end

        m = genmesh_rational1()
        @test nhours(m) == 8760
        @test nsteps(m) == 8760*2
        @test all(weight(m, s) == 1//2 for s in 1:(8760*2))
        @test all(hour(m, s) == (s+1)/2 for s in 1:(8760*2))
        @test all(step(m, h-1) == 2*h-1 for h in 1:8760)
        @test eachhour(m) == 1:8760
        @test eachstep(m) == 1:(8760*2)
    
    end


    let

        # TimeMesh where all timesteps are repetition of 1/4 hour then 3/4 hour
        function genmesh_rational2()
            w = repeat([1//4, 3//4], 8760)
            m = TimeMesh(w)
            return m
        end

        m = genmesh_rational2()
        @test nhours(m) == 8760
        @test nsteps(m) == 8760*2
        @test all(weight(m, s) == 1//4 for s in 1:2:(8760*2))
        @test all(weight(m, s) == 3//4 for s in 2:2:(8760*2))
        @test all(hour(m, s) == Rational((s-1)/2)+1 for s in 1:2:(8760*2))
        @test all(hour(m, s) == 1//4 + s/2 for s in 2:2:(8760*2))
        @test all(step(m, h-1) == 2*h-1 for h in 1:8760)
        @test eachhour(m) == 1:8760
        @test eachstep(m) == 1:(8760*2)    
    
    end


    let

        # TimeMesh where all timesteps are longer than 1 hour
        w = fill(2//1, 4)
        m = TimeMesh(w)

        @test nhours(m) == 8
        @test nsteps(m) == 4
        @test all(weight(m, s) == 2//1 for s in 1:4)
        @test [hour(m, s) for s in 1:4] == [1//1, 3//1, 5//1, 7//1]
        @test [step(m, h-1) for h in 1:8] == [1, 1, 2, 2, 3, 3, 4, 4]
        @test eachhour(m) == 1:8
        @test eachstep(m) == 1:4

    end


    let

        # Mixed sub-hourly, hourly, and longer-than-hourly timesteps
        w = [3//2, 1//2, 2//1]
        m = TimeMesh(w)

        @test nhours(m) == 4
        @test nsteps(m) == 3
        @test [hour(m, s) for s in 1:3] == [1//1, 5//2, 3//1]
        @test [step(m, h-1) for h in 1:4] == [1, 1, 3, 3]
        @test eachhour(m) == 1:4
        @test eachstep(m) == 1:3

    end


    let

        # Non-circular meshes keep the same time structure but disable wrapping.
        m = TimeMesh(fill(1//1, 4); circular=false)

        @test !iscircular(m)
        @test nhours(m) == 4
        @test nsteps(m) == 4
        @test all(weight(m, s) == 1//1 for s in 1:4)
        @test weight(m, 0) == weight(m, 1)
        @test weight(m, 5) == weight(m, 4)

    end

end

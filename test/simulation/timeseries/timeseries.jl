using Nosy: TimeMesh, Hourly, Stepwise, remesh
using Nosy: nhours, nsteps, eachhour, eachstep, shift, iscircular, mesh
using JuMP: AffExpr
using Test

@testset "Time series" begin

    let

        # testing Hourly time series
        v = [Float64(i) for i in 1:100]
        m = TimeMesh(fill(1//1, 100))
        h = Hourly(v, m)

        @test iscircular(h)
        @test nhours(h) == 100
        @test nsteps(h) == 100
        @test eachhour(h) == 1:100
        @test eachstep(h) == 1:100
        @test_throws MethodError resize!(h, 3)

        hc = copy(h)
        @test hc isa Hourly{Float64}
        @test mesh(hc) == m
        @test parent(hc) == parent(h)
        @test parent(hc) !== parent(h)

        hs = similar(h)
        @test hs isa Hourly{Float64}
        @test mesh(hs) == m
        @test length(hs) == length(h)

        hz = zero(h)
        @test hz isa Hourly{Float64}
        @test mesh(hz) == m
        @test parent(hz) == zeros(length(h))

        #modulo
        @test all(h[i] == v[i] for i in 1:100)
        @test all(h[i+100] == v[i] for i in 1:100)
        @test all(h[i+2*100] == v[i] for i in 1:100)
        @test all(h[i-100] == v[i] for i in 1:100)

        # algebra
        @test all((h + h )[i] == v[i] + v[i] for i in 1:100)
        @test all((h - h)[i] == 0. for i in 1:100)
        @test all((2. * h)[i] == 2. * v[i] for i in 1:100)
        @test all((h / 2.)[i] == v[i] / 2 for i in 1:100)

        # shift
        @test all(shift(h,3)[i] == h[i+3] for i in 1:100)

        # setindex
        let h2 = Hourly(v,m)
            h2[0] = -1
            @test h2[0] == -1.
        end

    end


    let

        # testing Stepwise time series
        v = [Float64(i) for i in 1:100*2]
        m = TimeMesh(fill(1//2, 100*2))
        s = Stepwise(v, m)

        @test iscircular(s)
        @test nhours(s) == 100
        @test nsteps(s) == 100*2
        @test eachhour(s) == 1:100
        @test eachstep(s) == 1:(100*2)
        @test_throws MethodError resize!(s, 3)

        sc = copy(s)
        @test sc isa Stepwise{Float64}
        @test mesh(sc) == m
        @test parent(sc) == parent(s)
        @test parent(sc) !== parent(s)

        ss = similar(s)
        @test ss isa Stepwise{Float64}
        @test mesh(ss) == m
        @test length(ss) == length(s)

        sz = zero(s)
        @test sz isa Stepwise{Float64}
        @test mesh(sz) == m
        @test parent(sz) == zeros(length(s))

        #modulo
        @test all(s[i] == v[i] for i in 1:100*2)
        @test all(s[i+2*100] == v[i] for i in 1:100*2)
        @test all(s[i+4*100] == v[i] for i in 1:100*2)
        @test all(s[i-2*100] == v[i] for i in 1:100*2)

        # algebra
        @test all((s + s )[i] == v[i] + v[i] for i in 1:100*2)
        @test all((s - s)[i] == 0. for i in 1:100*2)
        @test all((2. * s)[i] == 2. * v[i] for i in 1:100*2)
        @test all((s / 2.)[i] == v[i] / 2 for i in 1:100*2)

        # shift
        @test all(shift(s,3)[i] == s[i+3] for i in 1:100*2)

        # setindex
        let s2 = Stepwise(v,m)
            s2[0] = -1 # expect implicit conversion to Float64
            @test s2[0] == -1.
        end

        # Stepwise from Number
        let s3 = Stepwise(5., m)
            @test s3 isa Stepwise{Float64}
            @test nsteps(s3) == nsteps(m)
            @test all(s3[s] == 5. for s in eachstep(m))
        end

        # Stepwise from ~hourly data
        let s4 = Stepwise(Float64.(1:nhours(m)), m)
            @test s4 isa Stepwise{Float64}
            @test nsteps(s4) == nsteps(m)
            @test all(s4[2*h-1] == Float64(h) for h in eachhour(m))
        end

    end


    let

        # testing non-circular Hourly time series
        v = [Float64(i) for i in 1:5]
        m = TimeMesh(fill(1//1, 5); circular=false)
        h = Hourly(v, m)

        @test !iscircular(h)
        @test all(h[i] == v[i] for i in 1:5)
        @test h[0] == 0.0
        @test h[6] == 0.0
        @test h[0:2] == [0.0, 1.0, 2.0]
        @test h[[0, 1, 6]] == [0.0, 1.0, 0.0]
        @test collect(shift(h, 1)) == [2.0, 3.0, 4.0, 5.0, 5.0]
        @test collect(shift(h, -1)) == [1.0, 1.0, 2.0, 3.0, 4.0]

        let h2 = Hourly(v, m)
            h2[0] = -1
            h2[6] = -1
            @test h2.data == v
        end

    end


    let

        # testing non-circular Stepwise time series
        v = [Float64(i) for i in 1:5]
        m = TimeMesh(fill(1//1, 5); circular=false)
        s = Stepwise(v, m)

        @test !iscircular(s)
        @test all(s[i] == v[i] for i in 1:5)
        @test s[0] == 0.0
        @test s[6] == 0.0
        @test s[0:2] == [0.0, 1.0, 2.0]
        @test s[[0, 1, 6]] == [0.0, 1.0, 0.0]
        @test collect(shift(s, 2)) == [3.0, 4.0, 5.0, 5.0, 5.0]
        @test collect(shift(s, -2)) == [1.0, 1.0, 1.0, 2.0, 3.0]
        @test sum(s) == 12.0

        let s2 = Stepwise(v, m)
            s2[0] = -1
            s2[6] = -1
            @test s2.data == v
        end

    end


    let

        # testing Stepwise -> Hourly conversion
        v = [Float64(i) for i in 1:100*2]
        m = TimeMesh(repeat([1//4, 3//4], 100))
        s = Stepwise(v, m)

        h = Hourly(s)

        @test nhours(h) == 100
        @test nsteps(h) == 200
        @test eachhour(h) == 1:100
        @test eachstep(h) == 1:200

        @test all(h[i] == s[2*i-1] for i in 1:100)

    end


    let

        # testing Hourly -> Stepwise conversion
        v = [Float64(i) for i in 1:100]
        m = TimeMesh(repeat([1//4, 3//4], 100))
        h = Hourly(v, m)

        s = Stepwise(h)

        @test nhours(s) == 100
        @test nsteps(s) == 200
        @test eachhour(s) == 1:100
        @test eachstep(s) == 1:200

        @test all(s[i] == h[Int((i+1)/2)] for i in 1:2:200)
        @test all(s[i] == 3/4 * h[Int(i/2)] +1/4 * h[Int(i/2)+1] for i in 2:2:200)
        
    end


    let

        # illegal summation of Hourly and Stepwise
        v = [Float64(i) for i in 1:100]
        m = TimeMesh(repeat([1//4, 3//4], 100))
        h = Hourly(v, m)
        s = Stepwise(h)

        @test_throws ArgumentError s + h

    end


    let

        # testing Stepwise -> Hourly conversion with timesteps longer than one hour
        v = [10.0, 30.0]
        m = TimeMesh(fill(2//1, 2))
        s = Stepwise(v, m)

        h = Hourly(s)

        @test nhours(h) == 4
        @test nsteps(h) == 2
        @test all(isapprox.(h.data, [10.0, 20.0, 30.0, 20.0]))
        @test sum(s) == sum(h)

    end


    let

        # testing Stepwise -> Hourly conversion with mixed timestep lengths
        v = [10.0, 25.0, 30.0]
        m = TimeMesh([3//2, 1//2, 2//1])
        s = Stepwise(v, m)

        h = Hourly(s)

        @test all(isapprox.(h.data, [10.0, 20.0, 30.0, 20.0]))
        @test sum(s) == sum(h)

    end


    let

        # testing Hourly -> Stepwise conversion with timesteps longer than one hour
        h = Hourly([10.0, 20.0, 30.0, 20.0], TimeMesh(fill(2//1, 2)))

        s = Stepwise(h)

        @test nsteps(s) == 2
        @test all(isapprox.(s.data, [10.0, 30.0]))

    end


    let

        # testing direct Stepwise remeshing without an Hourly intermediate
        source = TimeMesh([1//2, 1//2, 3//1])
        target = TimeMesh([1//2, 7//2])
        s = Stepwise([10.0, 100.0, 30.0], source)

        t = remesh(s, target)

        @test mesh(t) == target
        @test t.data ≈ [55.0, 185 / 7]

        e = remesh(s, target; method=:exact)

        @test e.data == [10.0, 100.0]

        fine = TimeMesh(fill(1//1, 4))
        coarse = TimeMesh(fill(2//1, 2))
        u = Stepwise([10.0, 30.0], coarse)

        @test_throws ArgumentError remesh(u, fine)
        @test_throws ArgumentError remesh(s, target; method=:unknown)

        unrelated = TimeMesh([3//2, 5//2])
        @test_throws ArgumentError remesh(s, unrelated)
        @test_throws ArgumentError remesh(Stepwise(1.0, unrelated), fine)
        @test_throws ArgumentError remesh(Stepwise(1.0, fine), TimeMesh(fill(2//1, 2); circular=false))

    end

    let

        # average remeshing preserves constants and averages source intervals
        source = TimeMesh(fill(1//1, 24))
        target = TimeMesh(vcat(fill(4//1, 2), fill(2//1, 6), [4//1]))

        flow = remesh(Stepwise(1.0, source), target)

        @test all(isapprox.(flow.data, ones(nsteps(target))))
        @test sum(flow) ≈ 24.0

        values = remesh(Stepwise(Float64.(1:24), source), target)

        @test values.data == [3.0, 7.0, 10.0, 12.0, 14.0, 16.0, 18.0, 20.0, 20.0]
        @test remesh(Stepwise(Float64.(1:24), source), target; method=:exact).data ==
            [1.0, 5.0, 9.0, 11.0, 13.0, 15.0, 17.0, 19.0, 21.0]
        @test_throws ArgumentError remesh(values, source)

    end

    let

        # non-circular remeshing uses n-1 intervals; the last point is only a boundary
        source = TimeMesh(fill(1//1, 5); circular=false)
        target = TimeMesh([2//1, 2//1, 1//1]; circular=false)
        s = Stepwise([0.0, 0.0, 0.0, 0.0, 10.0], source)

        a = remesh(s, target)

        @test a.data == [0.0, 2.5, 10.0]

    end


    let

        # illegal summation of time series based on different meshes
        v = [Float64(i) for i in 1:100]
    
        m1 = TimeMesh(repeat([1//4, 3//4], 100))   
        m2 = TimeMesh(repeat([1//2, 1//2], 100))

        h1 = Hourly(v, m1)
        h2 = Hourly(v, m2)

        s1 = Stepwise(h1)
        s2 = Stepwise(h2)

        @test_throws ArgumentError s1 + s2
        @test_throws ArgumentError h1 + h2

    end


    let

        # summation of Hourly and Stepwise - Float64 version
        v = [Float64(i) for i in 1:200]
        m = TimeMesh(repeat([1//2, 1//2], 100))

        s = Stepwise(v, m)
        h = Hourly(s)

        @test sum(s) == Float64(sum(1:200)/2)
        @test sum(h) == Float64(sum(1:2:200))

    end

    let

        # summation of Stepwise - Float64 version with non-uniform weights
        v = Float64[10, 20, 30, 40, 50, 60]
        m = TimeMesh(repeat([1//4, 1//4, 1//2], 2))
        s = Stepwise(v, m)

        @test sum(s) == 70.0

    end


    let

        # summation of Hourly and Stepwise - GenericAffExpr version
        v = [AffExpr(i) for i in 1:200]
        m = TimeMesh(repeat([1//2, 1//2], 100))

        s = Stepwise(v, m)
        h = Hourly(s)

        @test sum(s) == AffExpr(sum(1:200)/2)
        @test sum(h) == AffExpr(sum(1:2:200))

    end

    let

        # summation of Stepwise - GenericAffExpr version with non-uniform weights
        v = AffExpr.([10, 20, 30, 40, 50, 60])
        m = TimeMesh(repeat([1//4, 1//4, 1//2], 2))
        s = Stepwise(v, m)

        @test sum(s) == AffExpr(70.0)

    end

    let

        # summation of Stepwise - GenericAffExpr version with long timesteps
        v = AffExpr.([10, 30])
        m = TimeMesh(fill(2//1, 2))
        s = Stepwise(v, m)
        h = Hourly(s)

        @test h == Hourly(AffExpr.([10, 20, 30, 20]), m)
        @test sum(s) == AffExpr(80.0)
        @test sum(s) == sum(h)

    end


    let

        # Broadcasting of Stepwise
        m = TimeMesh(repeat([1//2, 1//2], 100))
        v1 = Stepwise(1:200, m)
        v2 = Stepwise(201:400, m)

        @test (v1 .+ 1) isa Stepwise{Float64}
        @test (v1 .+ 1).data == Float64.(2:201)
        @test (v1 .+ v2) isa Stepwise{Float64}
        @test (v1 .+ v2).data == Float64.(1:200) + Float64.(201:400)
        @test (v1 .* v2) isa Stepwise{Float64}
        @test (v1 .* v2).data == Float64.(1:200) .* Float64.(201:400)

    end


end

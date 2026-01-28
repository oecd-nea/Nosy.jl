using Nosy: TimeMesh, Hourly, Stepwise
using Nosy: nhours, nsteps, eachhour, eachstep, shift
using JuMP: AffExpr
using Test

@testset "Time series" begin

    let

        # testing Hourly time series
        v = [Float64(i) for i in 1:100]
        m = TimeMesh(fill(1//1, 100))
        h = Hourly(v, m)

        @test nhours(h) == 100
        @test nsteps(h) == 100
        @test eachhour(h) == 1:100
        @test eachstep(h) == 1:100

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

        @test nhours(s) == 100
        @test nsteps(s) == 100*2
        @test eachhour(s) == 1:100
        @test eachstep(s) == 1:(100*2)

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

        # summation of Hourly and Stepwise - GenericAffExpr version
        v = [AffExpr(i) for i in 1:200]
        m = TimeMesh(repeat([1//2, 1//2], 100))

        s = Stepwise(v, m)
        h = Hourly(s)

        @test sum(s) == AffExpr(sum(1:200)/2)
        @test sum(h) == AffExpr(sum(1:2:200))

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

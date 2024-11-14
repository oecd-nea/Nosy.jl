using POSY2: TimeMesh
using POSY2: nhours, nsteps, weight, hour, step, eachhour, eachstep

@testset "Time series mesh" begin

    let
        
        # forbidden cases

        @test_throws ArgumentError TimeMesh([1//2, 1//1]) # sum of weights is not integer

        @test_throws ArgumentError TimeMesh([3//2, 1//2]) # first timestep is longer than one hour

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
        @test all(step(m, h) == h for h in 1:8760)
        @test eachhour(m) == 1:8760
        @test eachstep(m) == 1:8760
    
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
        @test all(step(m, h) == 2*h-1 for h in 1:8760)
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
        @test all(step(m, h) == 2*h-1 for h in 1:8760)
        @test eachhour(m) == 1:8760
        @test eachstep(m) == 1:(8760*2)    
    
    end

end
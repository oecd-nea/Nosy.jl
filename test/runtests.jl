using POSY2
using Test

@testset verbose=true "POSY2" begin

    include("tools.jl")

    include("simulation/_includes.jl")
    include("system/_includes.jl")

end
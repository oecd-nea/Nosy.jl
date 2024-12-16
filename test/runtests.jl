using Nosy
using Test

@testset verbose=true "Nosy" begin

    include("tools.jl")

    include("simulation/_includes.jl")
    include("system/_includes.jl")
    include("optim/_includes.jl")

end
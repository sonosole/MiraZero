module Mira
Base.__precompile__(true)


using Statistics: mean, std
import Statistics.mean

include("./kit/include.jl")
include("./base/include.jl")
include("./block/include.jl")
include("./backward/include.jl")
include("./loss/include.jl")



end

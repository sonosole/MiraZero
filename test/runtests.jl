using Test
using Mira
using Random

@testset "checking gradient" begin
    include("./checkgrad/acts.jl")
    include("./checkgrad/0-softmax.jl")
    include("./checkgrad/1-pool.jl")
    include("./checkgrad/2-linear.jl")
    include("./checkgrad/3-mlp.jl")
    include("./checkgrad/4-chain.jl")
    include("./checkgrad/5-conv1d.jl")
    include("./checkgrad/5-depthconv1d.jl")
    include("./checkgrad/7-scaler.jl")
    include("./checkgrad/8-ctc.jl")
    include("./checkgrad/9-ace.jl")
    include("./checkgrad/10-pool.jl")
    include("./checkgrad/znorm.jl")
    include("./checkgrad/ten2mat.jl")
    include("./checkgrad/pad.jl")
    include("./checkgrad/conv.jl")
    include("./advanced/jacobian.jl")
    include("./misc/convpool.jl")
    include("./misc/compare.jl")
end

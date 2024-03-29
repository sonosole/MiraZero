export Linear
export Dense
export MLP
export Maxout
export Affine
export Res0d, Res0dWithBN
export SelfLoopResNet
export SelfLoopCumulativeResNet
export MeanNormResDense
export SparseMasking, sparseLoss

include("./1-linear.jl")
include("./2-dense.jl")
include("./3-maxout.jl")
include("./4-affine.jl")
include("./5-Res0d.jl")
include("./5-Res0dWithBN.jl")
include("./6-SelfLoopResNet.jl")
include("./7-SelfLoopCumulativeResNet.jl")
include("./8-MeanNormResDense.jl")
include("./9-SparseMasking.jl")

include("./n-misc.jl")
include("./1-criterion.jl")

include("./2-ctc-cpu.jl")
include("./2-ctc-with-softmax.jl")
include("./2-ctc-without-softmax.jl")

include("./2-ctclike-with-softmax.jl")

include("./3-tcs-cpu.jl")
include("./3-tcs-with-softmax.jl")
include("./3-tcs-without-softmax.jl")

# include("./4-boundsctc-cpu.jl")
# include("./4-boundsctc-with-softmax.jl")
#
# include("./5-boundedctc-cpu.jl")
# include("./5-boundedctc-with-softmax.jl")
#
include("./6-tdc.jl")
include("./7-fast-ctc.jl")
include("./8-ace.jl")
include("./9-pool.jl")

include("./compare.jl")

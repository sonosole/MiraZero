@testset "check activation fn's gradient" begin
    Random.seed!(UInt(time_ns()))
    T = Array{Float64}

    @test checkgrad(min2max,  Variable(randn(2, 8), type=T))
    @test checkgrad(min2max!, Variable(randn(2, 8), type=T))
    @test checkgrad(sigmoid,  Variable(randn(2, 8), type=T))
    @test checkgrad(sigmoid!∘sin, Variable(randn(2, 8), type=T))

    @test checkgrad(softplus,  Variable(randn(2, 8), type=T))
    @test checkgrad(softplus!, Variable(randn(2, 8), type=T))

    @test checkgrad(exp, Variable(randn(2, 8), type=T))
    @test checkgrad(exp!∘sin, Variable(randn(2, 8), type=T))
    @test checkgrad(exp2, Variable(randn(2, 8), type=T))
    @test checkgrad(exp2!∘sin, Variable(randn(2, 8), type=T))
    @test checkgrad(exp10, Variable(randn(2, 8), type=T))
    @test checkgrad(exp10!∘sin, Variable(randn(2, 8), type=T))

    @test checkgrad(log, Variable(rand(2, 8) .+ 7, type=T))
    @test checkgrad(log!, Variable(rand(2, 8) .+ 7, type=T))
    @test checkgrad(log2, Variable(rand(2, 8) .+ 10, type=T))
    @test checkgrad(log2!, Variable(rand(2, 8) .+ 10, type=T))
    @test checkgrad(log10, Variable(rand(2, 8) .+ 10, type=T))
    @test checkgrad(log10!, Variable(rand(2, 8) .+ 10, type=T))

    @test checkgrad(abs, Variable(randn(2, 8), type=T))
    @test checkgrad(abs!, Variable(randn(2, 8), type=T))
    @test checkgrad(sqrt, Variable(rand(2, 8), type=T))
    @test checkgrad(sqrt!∘sin, Variable(rand(2, 8), type=T))
    @test checkgrad(inv, Variable(randn(2, 8), type=T))
    @test checkgrad(inv!∘sin, Variable(randn(2, 8), type=T))

    _reshape_(x) = reshape(x, (4,4))
    @test checkgrad(_reshape_, Variable(randn(2, 8), type=T))
    _flatten_(x) = flatten(x, from=2,to=3)
    @test checkgrad(_flatten_, Variable(randn(4, 3, 2), type=T))

    @test checkgrad(sec,  Variable(rand(2, 8), type=T))
    @test checkgrad(sec!, Variable(rand(2, 8), type=T))

    @test checkgrad(tan, Variable(randn(2, 8), type=T))
    @test checkgrad(atan, Variable(randn(2, 8), type=T))
    @test checkgrad(atan!, Variable(randn(2, 8), type=T))
    @test checkgrad(tan!∘sin, Variable(randn(2, 8), type=T))
    @test checkgrad(tand, Variable(randn(2, 8), type=T))
    @test checkgrad(tand!∘sin, Variable(randn(2, 8), type=T))
    @test checkgrad(tanh, Variable(randn(2, 8), type=T))
    @test checkgrad(tanh!∘sin, Variable(randn(2, 8), type=T))
    @test checkgrad(hardtanh, Variable(randn(2, 8), type=T))
    @test checkgrad(hardtanh!, Variable(randn(2, 8), type=T))
    @test checkgrad(tanhshrink, Variable(rand(2, 8), type=T))
    @test checkgrad(tanhshrink!, Variable(rand(2, 8), type=T))

    @test checkgrad(asin, Variable(uniform(Float64, (2,4), from=-0.9, to=-0.9), type=T))
    @test checkgrad(asin!, Variable(uniform(Float64, (2,4), from=-0.9, to=-0.9), type=T))
    @test checkgrad(sin, Variable(randn(2, 8), type=T))
    @test checkgrad(sin!, Variable(randn(2, 8), type=T))
    @test checkgrad(sinh, Variable(randn(2, 8), type=T))
    @test checkgrad(sinh!, Variable(randn(2, 8), type=T))
    @test checkgrad(asinh, Variable(randn(2, 8), type=T))
    @test checkgrad(asinh!, Variable(randn(2, 8), type=T))
    @test checkgrad(sinc, Variable(randn(2, 8), type=T))
    @test checkgrad(sinc!, Variable(randn(2, 8), type=T))
    @test checkgrad(sind, Variable(randn(2, 8), type=T))
    @test checkgrad(sind!, Variable(randn(2, 8), type=T))
    @test checkgrad(sinpi, Variable(randn(2, 8), type=T))
    @test checkgrad(sinpi!, Variable(randn(2, 8), type=T))
    @test checkgrad(linearsin, Variable(rand(2, 8), type=T))
    @test checkgrad(linearsin!, Variable(rand(2, 8), type=T))

    @test checkgrad(cos, Variable(randn(2, 8), type=T))
    @test checkgrad(cos!, Variable(randn(2, 8), type=T))
    @test checkgrad(cosh, Variable(randn(2, 8), type=T))
    @test checkgrad(cosh!, Variable(randn(2, 8), type=T))
    @test checkgrad(acos, Variable(uniform(Float64, (2,4), from=-0.9, to=-0.9), type=T))
    @test checkgrad(acos!, Variable(uniform(Float64, (2,4), from=-0.9, to=-0.9), type=T))
    @test checkgrad(acosh, Variable(rand(2, 8) .+ 1.2, type=T))
    @test checkgrad(acosh!, Variable(rand(2, 8) .+ 1.2, type=T))

    @test checkgrad(relu, Variable(randn(2, 8), type=T))
    @test checkgrad(relu!, Variable(randn(2, 8), type=T))
    @test checkgrad(relu1, Variable(randn(2, 8), type=T))
    @test checkgrad(relu1!, Variable(randn(2, 8), type=T))
    @test checkgrad(relu6, Variable(randn(2, 8), type=T))
    @test checkgrad(relu6!, Variable(randn(2, 8), type=T))
    @test checkgrad(leakyrelu, Variable(randn(2, 8), type=T))
    @test checkgrad(leakyrelu!, Variable(randn(2, 8), type=T))
    @test checkgrad(elu, Variable(randn(2, 8), type=T))
    @test checkgrad(elu!, Variable(randn(2, 8), type=T))
    @test checkgrad(selu, Variable(randn(2, 8), type=T))
    @test checkgrad(selu!, Variable(randn(2, 8), type=T))
    @test checkgrad(gelu, Variable(randn(2, 8), type=T))
    @test checkgrad(gelu!, Variable(randn(2, 8), type=T))
    @test checkgrad(celu, Variable(randn(2, 8), type=T))
    @test checkgrad(celu!, Variable(randn(2, 8), type=T))

    @test checkgrad(mish, Variable(randn(2, 8), type=T))
    @test checkgrad(mish!, Variable(randn(2, 8), type=T))
    @test checkgrad(swish, Variable(randn(2, 8), type=T))
    @test checkgrad(swish!, Variable(randn(2, 8), type=T))
    @test checkgrad(hardswish, Variable(randn(2, 8), type=T))
    @test checkgrad(hardswish!, Variable(randn(2, 8), type=T))
end

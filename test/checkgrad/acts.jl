@testset "check activation fn's gradient" begin

    using Random, Test
    Random.seed!(UInt(time_ns()))

    T = Array{Float64}

    @test checkgrad(min2max, Variable(randn(2, 8), type=T))

    @test checkgrad(relu, Variable(randn(2, 8), type=T))

    @test checkgrad(relu1, Variable(randn(2, 8), type=T))

    @test checkgrad(relu6, Variable(randn(2, 8), type=T))

    @test checkgrad(hardtanh, Variable(randn(2, 8), type=T))

    @test checkgrad(leakyrelu, Variable(randn(2, 8), type=T))

    @test checkgrad(sigmoid, Variable(randn(2, 8), type=T))

    @test checkgrad(swish, Variable(randn(2, 8), type=T))

    @test checkgrad(softplus, Variable(randn(2, 8), type=T))

    @test checkgrad(exp, Variable(randn(2, 8), type=T))

    @test checkgrad(log, Variable(rand(2, 8) .+ 7, type=T))

    @test checkgrad(abs, Variable(randn(2, 8), type=T))

    _reshape_(x) = reshape(x, (4,4))
    @test checkgrad(_reshape_, Variable(randn(2, 8), type=T))

    @test checkgrad(sqrt, Variable(rand(2, 8), type=T))

    @test checkgrad(tan, Variable(rand(2, 8), type=T))

    @test checkgrad(tanh, Variable(rand(2, 8), type=T))

    @test checkgrad(tand, Variable(rand(2, 8), type=T))

    @test checkgrad(tanhshrink, Variable(rand(2, 8), type=T))

    @test checkgrad(sin, Variable(rand(2, 8), type=T))

    @test checkgrad(sinc, Variable(rand(2, 8), type=T))

    @test checkgrad(sind, Variable(rand(2, 8), type=T))

    @test checkgrad(sinpi, Variable(rand(2, 8), type=T))

    @test checkgrad(linearsin, Variable(rand(2, 8), type=T))

    @test checkgrad(cos, Variable(rand(2, 8), type=T))

    @test checkgrad(inv, Variable(rand(2, 8), type=T))
    
end

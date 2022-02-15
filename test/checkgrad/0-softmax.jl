@testset "check softmax op's gradient" begin
    for d in [1 2 3 (1,2) (2,3) (1,3) (1,2,3)]
        @testset "check softmax op's gradient at dim = $d" begin
            DIMS = d
            TYPE = Array{Float64};

            # [1] prepare input data and its label
            inputdims = 64;
            timeSteps = 16;
            batchsize = 32;
            x = Variable(rand(inputdims, timeSteps, batchsize), type=TYPE, keepsgrad=true);
            l = Variable(rand(inputdims, timeSteps, batchsize), type=TYPE);

            # [2] forward and backward propagation
            probs = softmax(x; dims=DIMS)
            Loss1 = crossEntropyLoss(probs, l);
            Loss2 = mseLoss(probs, l);
            COST1 = loss(0.8*Loss1 + 0.2*Loss2)
            backward(COST1);
            GRAD = x.delta[1];

            # [3] with a samll change of a weight
            DELTA = 1e-5;
            x.value[1] += DELTA;

            # [4] forward and backward propagation with a samll change of a weight
            probs = softmax(x; dims=DIMS)
            Loss1 = crossEntropyLoss(probs, l);
            Loss2 = mseLoss(probs, l);
            COST2 = loss(0.8*Loss1 + 0.2*Loss2)
            backward(COST2);

            # [5] check if the auto-grad is true or not
            dLdW = (ᵛ(COST2)[1] - ᵛ(COST1)[1])/DELTA;   # numerical gradient
            err  = abs((dLdW-GRAD)/(GRAD+eps(Float64)))*100;  # relative error in %
            @test err < 1e-1
        end
    end
end
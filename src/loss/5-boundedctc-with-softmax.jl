export CRNN_BoundedCTC_With_Softmax


function CRNN_BoundedCTC_With_Softmax(x::Variable{Array{T}},
                                     seqlabels::Vector;
                                     blank::Int=1,
                                     bound::Int=2,
                                     reduction::String="seqlen") where T
    featdims, timesteps, batchsize = size(x)
    nlnp = zeros(T, 1, 1, batchsize)
    p = softmax(ᵛ(x), dims=1)
    r = zero(p)

    for b = 1:batchsize
        r[:,:,b], nlnp[b] = BoundedCTC(p[:,:,b], seqlabels[b], blank=blank, bound=bound)
    end

    Δ = p - r
    reduce3d(Δ, nlnp, seqlabels, reduction)
    y = Variable{T}([sum(nlnp)], x.backprop)

    if y.backprop
        y.backward = function ∇CRNN_BoundedCTC_With_Softmax()
            if needgrad(x)
                x ← δ(y) .* Δ
            end
        end
        addchild(y, x)
    end
    return y
end

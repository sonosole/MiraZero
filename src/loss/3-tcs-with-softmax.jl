export FNNSoftmaxTCSLoss
export RNNSoftmaxTCSLoss
export FRNNSoftmaxTCSLoss
export FRNNSoftmaxFocalTCSLoss
export FRNNSoftmaxTCSProbs

"""
    FNNSoftmaxTCSLoss(x::Variable,
                      seqlabels::Vector,
                      inputlens;
                      background::Int=1,
                      foreground::Int=2,
                      weight=1.0)

# Inputs
`x`         : 2-D Variable, a batch of concatenated input sequence\n
`seqlabels` : a batch of sequential labels, like [[i,j,k],[x,y],...]\n
`inputlens` : records each input sequence's length, like [20,17,...]\n
`weight`    : weight for TCS loss

# Structure
    ┌───┐
    │ │ │
    │ W ├──►─┐
    │ │ │    │
    └───┘    │
    ┌───┐    │    ┌───┐          ┌───┐
    │ │ │  ┌─┴─┐  │ │ │ softmax  │ │ │   ┌───────┐
    │ Z ├─►│ × ├─►│ X ├─────────►│ P ├──►│TCSLOSS│◄── (seqLabel)
    │ │ │  └───┘  │ │ │          │ │ │   └───┬───┘
    └───┘         └─┬─┘          └─┬─┘       │
                    │              │+        ▼
                  ┌─┴─┐            ▼       ┌─┴─┐
                  │ │ │          ┌─┴─┐ -   │ │ │
                  │ δ │◄─────────┤ - │──◄──┤ r │
                  │ │ │          └───┘     │ │ │
                  └───┘                    └───┘
"""
function FNNSoftmaxTCSLoss(x::Variable{T},
                           seqlabels::Vector,
                           inputlens;
                           background::Int=1,
                           foreground::Int=2,
                           weight=1.0) where T
    batchsize = length(seqlabels)
    nlnp = zeros(eltype(x), batchsize)
    I, F = indexbounds(inputlens)
    p = softmax(ᵛ(x); dims=1)
    r = zero(ᵛ(x))

    Threads.@threads for b = 1:batchsize
        span = I[b]:F[b]
        r[:,span], nlnp[b] = TCS(p[:,span], seqlabels[b], background=background, foreground=foreground)
    end

    Δ = p - r
    y = Variable{T}([sum(nlnp)], x.backprop)

    if y.backprop
        y.backward = function FNNSoftmaxTCSLoss_Backward()
            if need2computeδ!(x)
                if weight==1.0
                    δ(x) .+= δ(y) .* Δ
                else
                    δ(x) .+= δ(y) .* Δ .* weight
                end
            end
            ifNotKeepδThenFreeδ!(y)
        end
        addchild(y, x)
    end
    return y
end


"""
    RNNSoftmaxTCSLoss(x::Variable,
                      seqlabels::Vector,
                      inputlens;
                      background::Int=1,
                      foreground::Int=2,
                      reduction::String="seqlen",
                      weight=1.0)

a batch of padded input sequence is processed by neural networks into `x`

# Inputs
`x`         : 3-D Variable with shape (featdims,timesteps,batchsize), a batch of padded input sequence\n
`seqlabels` : a batch of sequential labels, like [[i,j,k],[x,y],...]\n
`inputlens` : records each input sequence's length, like [20,17,...]\n
`weight`    : weight for TCS loss

# Structure
    ┌───┐
    │ │ │
    │ W ├──►─┐
    │ │ │    │
    └───┘    │
    ┌───┐    │    ┌───┐          ┌───┐
    │ │ │  ┌─┴─┐  │ │ │ softmax  │ │ │   ┌───────┐
    │ Z ├─►│ × ├─►│ X ├─────────►│ P ├──►│TCSLOSS│◄── (seqLabel)
    │ │ │  └───┘  │ │ │          │ │ │   └───┬───┘
    └───┘         └─┬─┘          └─┬─┘       │
                    │              │+        ▼
                  ┌─┴─┐            ▼       ┌─┴─┐
                  │ │ │          ┌─┴─┐ -   │ │ │
                  │ δ │◄─────────┤ - │──◄──┤ r │
                  │ │ │          └───┘     │ │ │
                  └───┘                    └───┘
"""
function RNNSoftmaxTCSLoss(x::Variable{T},
                           seqlabels::Vector,
                           inputlens;
                           background::Int=1,
                           foreground::Int=2,
                           reduction::String="seqlen",
                           weight=1.0) where T
    batchsize = length(seqlabels)
    nlnp = zeros(eltype(x), batchsize)
    p = zero(ᵛ(x))
    r = zero(ᵛ(x))

    Threads.@threads for b = 1:batchsize
        Tᵇ = inputlens[b]
        p[:,1:Tᵇ,b] = softmax(x.value[:,1:Tᵇ,b]; dims=1)
        r[:,1:Tᵇ,b], nlnp[b] = TCS(p[:,1:Tᵇ,b], seqlabels[b], background=background, foreground=foreground)
    end

    Δ = p - r
    reduce3d(Δ, nlnp, seqlabels, reduction)
    y = Variable{T}([sum(nlnp)], x.backprop)

    if y.backprop
        y.backward = function RNNSoftmaxTCSLoss_Backward()
            if need2computeδ!(x)
                if weight==1.0
                    δ(x) .+= δ(y) .* Δ
                else
                    δ(x) .+= δ(y) .* Δ .* weight
                end
            end
            ifNotKeepδThenFreeδ!(y)
        end
        addchild(y, x)
    end
    return y
end


"""
    FRNNSoftmaxTCSLoss(x::Variable,
                       seqlabels::Vector;
                       background::Int=1,
                       foreground::Int=2,
                       reduction::String="seqlen",
                       weight=1.0)

# Main Inputs
`x`            : 3-D Variable with shape (featdims,timesteps,batchsize), resulted by a batch of padded input sequence\n
`seqlabels`    : a batch of sequential labels, like [[i,j,k],[x,y],...]\n
`weight`       : weight for TCS loss

# Structure
    ┌───┐
    │ │ │
    │ W ├──►─┐
    │ │ │    │
    └───┘    │
    ┌───┐    │    ┌───┐          ┌───┐
    │ │ │  ┌─┴─┐  │ │ │ softmax  │ │ │   ┌───────┐
    │ Z ├─►│ × ├─►│ X ├─────────►│ P ├──►│TCSLOSS│◄── (seqLabel)
    │ │ │  └───┘  │ │ │          │ │ │   └───┬───┘
    └───┘         └─┬─┘          └─┬─┘       │
                    │              │+        ▼
                  ┌─┴─┐            ▼       ┌─┴─┐
                  │ │ │          ┌─┴─┐ -   │ │ │
                  │ δ │◄─────────┤ - │──◄──┤ r │
                  │ │ │          └───┘     │ │ │
                  └───┘                    └───┘
"""
function FRNNSoftmaxTCSLoss(x::Variable{T},
                            seqlabels::Vector;
                            background::Int=1,
                            foreground::Int=2,
                            reduction::String="seqlen",
                            weight=1.0) where T
    featdims, timesteps, batchsize = size(x)
    nlnp = zeros(eltype(x), batchsize)
    p = softmax(ᵛ(x); dims=1)
    r = zero(ᵛ(x))

    Threads.@threads for b = 1:batchsize
        r[:,:,b], nlnp[b] = TCS(p[:,:,b], seqlabels[b], background=background, foreground=foreground)
    end

    Δ = p - r
    reduce3d(Δ, nlnp, seqlabels, reduction)
    y = Variable{T}([sum(nlnp)], x.backprop)

    if y.backprop
        y.backward = function FRNNSoftmaxTCSLoss_Backward()
            if need2computeδ!(x)
                if weight==1.0
                    δ(x) .+= δ(y) .* Δ
                else
                    δ(x) .+= δ(y) .* Δ .* weight
                end
            end
            ifNotKeepδThenFreeδ!(y)
        end
        addchild(y, x)
    end
    return y
end


function FRNNSoftmaxTCSProbs(x::Variable{T}, seqlabels::Vector; background::Int=1, foreground::Int=2) where T
    featdims, timesteps, batchsize = size(x)
    nlnp = zeros(eltype(x), batchsize)
    p = softmax(ᵛ(x); dims=1)
    r = zero(ᵛ(x))

    Threads.@threads for b = 1:batchsize
        r[:,:,b], nlnp[b] = TCS(p[:,:,b], seqlabels[b], background=background, foreground=foreground)
    end

    𝒑 = Variable{T}(exp(T(-nlnp)), x.backprop)
    Δ = p - r

    if 𝒑.backprop
        𝒑.backward = function FRNNSoftmaxCTCProbs_Backward()
            if need2computeδ!(x)
                δ(x) .+= δ(𝒑) .* Δ
            end
            ifNotKeepδThenFreeδ!(𝒑)
        end
        addchild(𝒑, x)
    end
    return 𝒑
end


function FRNNSoftmaxFocalTCSLoss(x::Variable{T},
                                 seqlabels::Vector;
                                 background::Int=1,
                                 foreground::Int=2,
                                 reduction::String="seqlen",
                                 weight=1.0) where T
    featdims, timesteps, batchsize = size(x)
    S = eltype(x)
    nlnp = zeros(S, 1, 1, batchsize)
    p = softmax(ᵛ(x), dims=1)
    r = zero(ᵛ(x))
    𝜸 = S(gamma)
    𝟙 = S(1.0f0)

    Threads.@threads for b = 1:batchsize
        r[:,:,b], nlnp[b] = TCS(p[:,:,b], seqlabels[b], background=background, foreground=foreground)
    end

    𝒍𝒏𝒑 = T(-nlnp)
    𝒑 = exp(𝒍𝒏𝒑)
    𝒌 = @.  (𝟙 - 𝒑)^(𝜸-𝟙) * (𝟙 - 𝒑 - 𝜸*𝒑*𝒍𝒏𝒑)
    t = @. -(𝟙 - 𝒑)^𝜸 * 𝒍𝒏𝒑
    Δ = p - r
    reduce3d(Δ, t, seqlabels, reduction)
    y = Variable{T}([sum(t)], x.backprop)

    if y.backprop
        y.backward = function FRNNSoftmaxFocalTCSLoss_Backward()
            if need2computeδ!(x)
                if weight==1.0
                    δ(x) .+= δ(y) .* 𝒌 .* Δ
                else
                    δ(x) .+= δ(y) .* 𝒌 .* Δ .* S(weight)
                end
            end
            ifNotKeepδThenFreeδ!(y)
        end
        addchild(y, x)
    end
    return y
end

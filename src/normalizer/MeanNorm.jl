"""
# Summary
    mutable struct MeanNorm <: Normalizer
# Fields
    β        :: VarOrNil                        # shifting params
    μ        :: Union{AbstractArray,Nothing}    # running average
    views    :: Union{NTuple,Nothing}           # views to get the statistical mean
    training :: Bool                            # if trainning then true
    momentum :: AbstractFloat                   # smoothing const for moving average

Applies mean normalization over a N-dimensional input

"""
mutable struct MeanNorm <: Normalizer
    β::VarOrNil                        # shifting params
    μ::Union{AbstractArray,Nothing}    # running average
    views::Union{NTuple,Nothing}
    training::Bool
    momentum::AbstractFloat
    function MeanNorm(;ndims::Int,
                      keptdims::Union{Tuple,Int},    # must be unique and sorted and positive
                      keptsize::Union{Tuple,Int},    # must be positive
                      momentum::AbstractFloat=0.1,   # smoothing const
                      type::Type=Array{Float32})

        shape, views = ShapeAndViews(ndims, keptdims, keptsize);
        β = Variable{type}(Zeros(type, shape), true, true, true);
        μ = Zeros(type, shape);
        T = eltype(type);
        new(β, μ, views, true, T(momentum))
    end
    function MeanNorm(training, momentum)
        new(nothing, nothing, nothing, training, momentum)
    end
end

function clone(this::MeanNorm; type::Type=Array{Float32})
    cloned = MeanNorm(this.training, this.momentum)
    cloned.β = clone(this.β, type=type)
    cloned.μ =  type(this.μ)
    cloned.views =   this.views
    return cloned
end

function Base.show(io::IO, m::MeanNorm)
    SIZE = size(m.β.value)
    TYPE = typeof(m.β.value)
    print(io, "MeanNorm(size(β)=$SIZE; type=$TYPE)")
end

function paramsof(m::MeanNorm)
    params = Vector{Variable}(undef,1)
    params[1] = m.β
    return params
end

function xparamsof(m::MeanNorm)
    xparams = Vector{XVariable}(undef,1)
    xparams[1] = ('b', m.β)
    return xparams
end

function nparamsof(model::MeanNorm)
    return 2*length(model.β)
end

elsizeof(m::MeanNorm) = elsizeof(m.β)

function bytesof(model::MeanNorm, unit::String="MB")
    n = nparamsof(model) * elsizeof(model)
    return blocksize(n, uppercase(unit))
end


function forward(M::MeanNorm, x::Variable{T}) where T
    β = M.β         # shifting params
    μ = M.μ         # statistical mean
    ρ = M.momentum  # smoothing const
    v = M.views
    n = length(β) / length(x)
    μₓ = sum(ᵛ(x), dims=v) .* n
    y  = Variable{T}(ᵛ(x) .- μₓ .+ ᵛ(β), x.backprop)

    if y.backprop
        @. μ = (1 - ρ) * μ + ρ * μₓ    # running mean
        y.backward = function ∇MeanNorm()
            if needgrad(x)
                x ← δ(y) .- sum(δ(y), dims=v) .* n
            end
            if needgrad(β)
                β ← sum(δ(y), dims=v) .+ zero(β)
            end
        end
        addchild(y, x)
    end
    return y
end


function predict(M::MeanNorm, x::AbstractArray)
    β = ᵛ(M.β)   # learned shifting param
    μ =   M.μ    # statistical mean param
    return x .- μ .+ β
end

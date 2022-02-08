function Base.maximum(x::Variable{T}; dims::Union{Int,NTuple{N,Int}}=1) where {T,N}
    y = Variable{T}(maximum(ᵛ(x), dims=dims), x.backprop)
    if x.backprop
        mask = ᵛ(x) .== ᵛ(y)
        y.backward = function maximumBackward(δy)
            if need2computeδ!(x)
                δ(x) .+= δy .* mask
            end
            ifNotKeepδThenFreeδ!(y)
        end
        addchild(y, x)
    end
    return y
end

function Base.minimum(x::Variable{T}; dims::Union{Int,NTuple{N,Int}}=1) where {T,N}
    y = Variable{T}(minimum(ᵛ(x), dims=dims), x.backprop)
    if x.backprop
        mask = ᵛ(x) .== ᵛ(y)
        y.backward = function minimumBackward(δy)
            if need2computeδ!(x)
                δ(x) .+= δy .* mask
            end
            ifNotKeepδThenFreeδ!(y)
        end
        addchild(y, x)
    end
    return y
end

function Base.sum(x::Variable{T}; dims::Union{Int,NTuple{N,Int}}=1) where {T,N}
    y = Variable{T}(sum(ᵛ(x), dims=dims), x.backprop)
    if x.backprop
        y.backward = function sumBackward(δy)
            if need2computeδ!(x)
                δ(x) .+= δy
            end
            ifNotKeepδThenFreeδ!(y)
        end
        addchild(y, x)
    end
    return y
end


function mean(x::Variable{T}; dims::Union{Int,NTuple{N,Int}}=1) where {T,N}
    n = eltype(x)(1) / prod(size(x, i) for i in dims)
    μ = Variable{T}(sum(ᵛ(x), dims=dims) .* n, x.backprop)
    if x.backprop
        μ.backward = function meanBackward(δμ)
            if need2computeδ!(x)
                δ(x) .+= δμ .* n
            end
            ifNotKeepδThenFreeδ!(μ);
        end
        addchild(μ, x)
    end
    return μ
end


function maxmin(x::Variable{T}; dims1::Int, dims2::Int) where T
    t = minimum(maximum(ᵛ(x), dims=dims1), dims=dims2)
    y = Variable{T}(t, x.backprop)
    if x.backprop
        mask = ᵛ(x) .== ᵛ(y)
        y.backward = function maxminBackward(δy)
            if need2computeδ!(x)
                δ(x) .+= δy .* mask
            end
            ifNotKeepδThenFreeδ!(y);
        end
        addchild(y, x)
    end
    return y
end


function maxmin(x::AbstractArray; dims1::Int, dims2::Int)
    return minimum( maximum(x, dims=dims1), dims=dims2)
end

function Base.minmax(x::Variable{T}; dims1::Int, dims2::Int) where T
    return maxmin(x; dims1=dims2, dims2=dims1)
end


function Base.minmax(x::AbstractArray; dims1::Int, dims2::Int)
    return maximum(minimum(x, dims=dims1), dims=dims2)
end


function linearpool(x::Variable{T}; dims::Union{Int,NTuple{N,Int}}=1) where {T,N}
    Σxᵢ² = sum(ᵛ(x) .* ᵛ(x), dims=dims)     # Σ xᵢ·xᵢ
    Σxᵢ  = sum(ᵛ(x),         dims=dims)     # Σ xᵢ
    y    = Variable{T}(Σxᵢ² ./ Σxᵢ, x.backprop)
    if x.backprop
        TWO = eltype(x)(2.0f0)
        y.backward = function linearpoolBackward(δy)
            if need2computeδ!(x)
                δ(x) .+= (TWO .* ᵛ(x) .- ᵛ(y)) ./ Σxᵢ .* δy
            end
            ifNotKeepδThenFreeδ!(y);
        end
        addchild(y, x)
    end
    return y
end


"""
    linearpool(x::AbstractArray; dims=1) -> y

    y = (Σᵢ xᵢ .* xᵢ) ./ Σᵢ xᵢ
"""
function linearpool(x::AbstractArray; dims::Union{Int,NTuple{N,Int}}=1) where N
    return sum(x .* x, dims=dims) ./ sum(x, dims=dims)
end


function exppool(x::Variable{T}; dims::Union{Int,NTuple{N,Int}}=1) where {T,N}
    eˣ  = exp.(ᵛ(x))
    Σeˣⁱxᵢ = sum(eˣ .* ᵛ(x), dims=dims)   # Σ exp(xᵢ)·xᵢ
    Σeˣⁱ = sum(eˣ, dims=dims)             # Σ exp(xᵢ)
    y  = Variable{T}(Σeˣⁱxᵢ ./ Σeˣⁱ, x.backprop)
    if y.backprop
        ONE = eltype(x)(1.0f0)
        y.backward = function exppoolBackward(δy)
            if need2computeδ!(x)
                δ(x) .+= eˣ ./ Σeˣⁱ .* (ONE .+ ᵛ(x) .- ᵛ(y)) .* δy
            end
            ifNotKeepδThenFreeδ!(y);
        end
        addchild(y, x)
    end
    return y
end


"""
    exppool(x::AbstractArray; dims=1) -> y

    y = (Σᵢ exp.(xᵢ) .* xᵢ) ./ Σᵢ exp.(xᵢ)
"""
function exppool(x::AbstractArray; dims::Union{Int,NTuple{N,Int}}=1) where N
    e = exp.(x)
    return sum(e .* x, dims=dims) ./ sum(e, dims=dims)
end



export mean
export maxmin
export linearpool
export exppool

function invpermdims(pdims::Vector{Int})
    newdims = Vector{Int}(undef, length(pdims))
    for (i, d) in enumerate(pdims)
        @inbounds newdims[d] = i
    end
    return newdims
end

function invpermdims(pdims::NTuple{D,Int}) where D
    newdims = Vector{Int}(undef, D)
    for (i, d) in enumerate(pdims)
        @inbounds newdims[d] = i
    end
    return newdims
end

function Base.permutedims(x::Variable{T}, d::Vector{Int}) where T
    assertdim(x, length(d))
    y = Variable{T}(permutedims(ᵛ(x), d), x.backprop)

    if y.backprop
        y.backward = function ∇permutedims()
            if needgrad(x)
                x ← permutedims(δ(y), invpermdims(d))
            end
            ifNotKeepδThenFreeδ!(y)
        end
        addchild(y, x)
    end
    return y
end

function Base.permutedims(x::Variable{T}, d::NTuple{D, Int}) where {T,D}
    assertdim(x, D)
    y = Variable{T}(permutedims(ᵛ(x), d), x.backprop)

    if y.backprop
        y.backward = function ∇permutedims()
            if needgrad(x)
                x ← permutedims(δ(y), invpermdims(d))
            end
            ifNotKeepδThenFreeδ!(y)
        end
        addchild(y, x)
    end
    return y
end


function Base.adjoint(x::Variable{T}) where T
    y = Variable{T}(ᵛ(x)', x.backprop)
    if y.backprop
        y.backward = function ∇adjoint()
            if needgrad(x)
                x ← δ(y)'
            end
            ifNotKeepδThenFreeδ!(y)
        end
        addchild(y, x)
    end
    return y
end


function Base.transpose(x::Variable{T}) where T
    y = Variable{T}(transpose(ᵛ(x)), x.backprop)
    if y.backprop
        y.backward = function ∇transpose()
            if needgrad(x)
                x ← transpose(ᵟ(y))
            end
            ifNotKeepδThenFreeδ!(y)
        end
        addchild(y, x)
    end
    return y
end


function Base.reshape(x::Variable{T}, newsize::Dims{N}) where {T,N}
    y = Variable{T}( reshape(ᵛ(x), newsize), x.backprop )
    if y.backprop
        y.backward = function ∇reshape()
            if needgrad(x)
                x ← reshape(δ(y), x.shape)
            end
            ifNotKeepδThenFreeδ!(y)
        end
        addchild(y, x)
    end
    return y
end

function Base.reshape(x::Variable{T}, shape::Int...) where T
    y = Variable{T}( reshape(ᵛ(x), shape), x.backprop )
    if y.backprop
        y.backward = function ∇reshape()
            if needgrad(x)
                x ← reshape(δ(y), x.shape)
            end
            ifNotKeepδThenFreeδ!(y)
        end
        addchild(y, x)
    end
    return y
end

function Base.reshape(x::Variable{T}, s₁::Int, s₂::Int) where T
    y = Variable{T}( reshape(ᵛ(x), s₁, s₂), x.backprop )
    if y.backprop
        y.backward = function ∇reshape()
            if needgrad(x)
                x ← reshape(δ(y), x.shape)
            end
            ifNotKeepδThenFreeδ!(y)
        end
        addchild(y, x)
    end
    return y
end

function Base.reshape(x::Variable{T}, s₁::Int, s₂::Int, s₃::Int) where T
    y = Variable{T}( reshape(ᵛ(x), s₁, s₂, s₃), x.backprop )
    if y.backprop
        y.backward = function ∇reshape()
            if needgrad(x)
                x ← reshape(δ(y), x.shape)
            end
            ifNotKeepδThenFreeδ!(y)
        end
        addchild(y, x)
    end
    return y
end


export flatten
export squeeze
export unsqueeze

"""
    flatten(x::Variable; from::Int=2, to::Int=ndims(x)) -> y::Variable
Flattens a contiguous range of dimentions of `x` into a tensor `y`. Suppose sizex = size(`x`), then
+ size(x) == (*, sizex[from], ..., sizex[to], *)
+ size(y) == (*, ∏ₖsizex[k], *), k in `from`:`to`
# Example
```
julia> x = Variable(reshape(collect(1:3*4*2),3,4,2))
 Leaf's value is 3×4×2 Array{Float32, 3}:
[:, :, 1] =
 1.0  4.0  7.0  10.0
 2.0  5.0  8.0  11.0
 3.0  6.0  9.0  12.0

[:, :, 2] =
 13.0  16.0  19.0  22.0
 14.0  17.0  20.0  23.0
 15.0  18.0  21.0  24.0

julia> y = flatten(x, from=2,to=3)
 None Leaf's value is 3×8 Matrix{Float32}:
 1.0  4.0  7.0  10.0  13.0  16.0  19.0  22.0
 2.0  5.0  8.0  11.0  14.0  17.0  20.0  23.0
 3.0  6.0  9.0  12.0  15.0  18.0  21.0  24.0
```
"""
function flatten(x::Variable; from::Int=2, to::Int=ndims(x))
    if from == to
        return x
    end

    D = ndims(x)
    Δ = to - from

    if from == 1 && to == D
        return reshape(x, prod(size(x)), 1)
    end

    D  < from && error("from dim kwarg exceeded the dimention of input")
    D  < to   && error("to dim kwarg exceeded the dimention of input")
    to < from && error("from dim shall be less equal than to dim")

    xshape = size(x)
    merged = prod(xshape[i] for i in from:to)
    newndim = D - Δ
    newsize = ntuple(newndim) do i
        i  < from && return xshape[i]
        i == from && return merged
        return xshape[i+Δ]
    end
    return reshape(x, newsize)
end

"""
    flatten(x::AbstractArray; from::Int=2, to::Int=ndims(x)) -> y::AbstractArray
Flattens a contiguous range of dimentions of `x` into a tensor `y`. Suppose sizex = size(`x`), then
+ size(x) == (*, sizex[from], ..., sizex[to], *)
+ size(y) == (*, ∏ₖsizex[k], *), k in `from`:`to`
# Example
```
julia> x = reshape(collect(1:3*4*2),3,4,2,1)
3×4×2×1 Array{Int64, 4}:
[:, :, 1, 1] =
 1  4  7  10
 2  5  8  11
 3  6  9  12

[:, :, 2, 1] =
 13  16  19  22
 14  17  20  23
 15  18  21  24

julia> y = flatten(x, from=2,to=4)
3×8 Matrix{Int64}:
 1  4  7  10  13  16  19  22
 2  5  8  11  14  17  20  23
 3  6  9  12  15  18  21  24
```
"""
function flatten(x::AbstractArray; from::Int=2, to::Int=ndims(x))
    if from == to
        return x
    end

    D = ndims(x)
    Δ = to - from

    if from == 1 && to == D
        return reshape(x, prod(size(x)), 1)
    end

    D  < from && error("from dim kwarg exceeded the dimention of input")
    D  < to   && error("to dim kwarg exceeded the dimention of input")
    to < from && error("from dim shall be less equal than to dim")

    xshape = size(x)
    merged = prod(xshape[i] for i in from:to)
    newndim = D - Δ
    newsize = ntuple(newndim) do i
        i  < from && return xshape[i]
        i == from && return merged
        return xshape[i+Δ]
    end
    return reshape(x, newsize)
end


"""
    squeeze(x::Union{Variable, AbstractArray}; dims::Union{Nothing, Int, Dims}=nothing)

Returns a tensor with all specified dimensions of `x` of size 1 removed.
`WARNING`: If the tensor has a batch dimension of size 1, then squeeze(`x`)
will also remove the batch dimension, which can lead to unexpected errors.
Consider specifying only the dims you wish to be squeezed.

# Exmaple
```
julia> x = rand(1, 4, 1, 3, 1, 1, 2);
julia> squeeze(x, dims=(1,3,5))  |> size
(4, 3, 1, 2)
julia> squeeze(x) |> size
(4, 3, 2)
```
"""
function squeeze(x::Union{Variable, AbstractArray}; dims::Union{Nothing, Int, Dims}=nothing)
    shape = Vector{Int}(undef, 0)
    sizex = size(x)
    if isnothing(dims)
        for d in sizex
            if d ≠ 1
                push!(shape, d)
            end
        end
    elseif dims isa Int
        for (i, d) in enumerate(sizex)
            if d ≠ 1 || i ≠ dims
                push!(shape, d)
            end
        end
    else
        for (i, d) in enumerate(sizex)
            if d ≠ 1 || i ∉ dims
                push!(shape, d)
            end
        end
    end
    return reshape(x, ntuple(i -> shape[i], length(shape)))
end


"""
    unsqueeze(x::Union{Variable, AbstractArray}; dims::Union{Int, Dims})

Returns a new tensor with a dimension of size 1 inserted at the specified positions.

# Exmaple
```
julia> x = rand(1,2,3,4,5);
julia> unsqueeze(x, dims=3) |> size
(1, 2, 1, 3, 4, 5)
julia> unsqueeze(x, dims=(3,5)) |> size
(1, 2, 1, 3, 4, 1, 5)
```
"""
function unsqueeze(x::Union{Variable, AbstractArray}; dims::Union{Int, Dims})
    shape = Vector{Int}(undef, 0)
    sizex = size(x)
    if dims isa Int
        for (i, d) in enumerate(sizex)
            isequal(i, dims) && push!(shape, 1)
            push!(shape, d)
        end
    else
        for (i, d) in enumerate(sizex)
            in(i, dims) && push!(shape, 1)
            push!(shape, d)
        end
    end
    return reshape(x, ntuple(i -> shape[i], length(shape)))
end

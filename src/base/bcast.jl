"""
    axes2reduce(z, x) -> axes::Vector{Int}
axes need to be reduced, `z` and `x` comes from `z = broadcast(::typeof(+-*/...), x, y)`\n

# Example
    axes2reduce(rand(3,4,5),rand(1,4))    -> (1,3)
    axes2reduce(rand(3,4,5),rand(1,4,1))  -> (1,3)
"""
function axes2reduce(z, x)
    a = VecInt(undef, 0)
    for i = 1:ndims(z)
        if size(x, i) == 1
            push!(a, i)
        end
    end
    return a
end


"""
    unbcast(δx::AbstractArray, x::AbstractArray) -> ∇x

reduced `δx` to `∇x` according to shape difference from `x` and `δx`

# Params
`x`  : comes from `z = broadcast(::typeof(+-*/...), x, y)`\n
`δx` : unreduced gradient, i.e. `δx = δz .* ∂z/∂x`\n
`∇x` : reduced gradient, i.e. ⤓⤓⤓\n
       Δx = sum(δx, dims=axes2reduce(δx, x)) # reduced but still has redundant dimensions\n
       ∇x = reshape(Δx, size(x))
"""
function unbcast(δx::AbstractArray, x::AbstractArray)
    if size(δx) == size(x)
        return δx
    elseif length(δx) == length(x)
        return reshape(δx, size(x))
    else
        Δx = sum(δx, dims=axes2reduce(δx,x))
        return reshape(Δx, size(x))
    end
end

import Base.Broadcast.broadcasted
const TensorOrReal = Union{AbstractArray, Real}

@inline function samesize(x::Union{Variable,AbstractArray,Real}, y::Union{Variable,AbstractArray,Real})
    size(x) == size(y)
end

# z = x .+ y
function broadcasted(::typeof(+), x::Variable{T1}, y::Variable{T2}) where {T1,T2}
    samesize(x, y) && return (x + y)

    T = vartype(T1, T2)
    z = Variable{T}(ᵛ(x) .+ ᵛ(y), x.backprop || y.backprop)
    if z.backprop
        z.backward = function ∇DotAdd()
            if needgrad(x)
                δx = δ(z)
                x ← unbcast(δx, ᵛ(x))
            end
            if needgrad(y)
                δy = δ(z)
                y ← unbcast(δy, ᵛ(y))
            end
        end
        addchild(z, x)
        addchild(z, y)
    end
    return z
end


function broadcasted(::typeof(+), x::Variable{T}, y::TensorOrReal) where T
    samesize(x, y) && return (x + y)

    z = Variable{T}(ᵛ(x) .+ y, x.backprop)
    if z.backprop
        z.backward = function ∇DotAdd()
            if needgrad(x)
                x ← unbcast(δ(z), ᵛ(x))
            end
        end
        addchild(z, x)
    end
    return z
end


function broadcasted(::typeof(+), x::TensorOrReal, y::Variable{T}) where T
    samesize(x, y) && return (x + y)

    z = Variable{T}(x .+ ᵛ(y), y.backprop)
    if z.backprop
        z.backward = function ∇DotAdd()
            if needgrad(y)
                y ← unbcast(δ(z), ᵛ(y))
            end
        end
        addchild(z, y)
    end
    return z
end


# z = x .- y
function broadcasted(::typeof(-), x::Variable{T1}, y::Variable{T2}) where {T1,T2}
    samesize(x, y) && return (x - y)

    T = vartype(T1, T2)
    z = Variable{T}(ᵛ(x) .- ᵛ(y), x.backprop || y.backprop)
    if z.backprop
        z.backward = function ∇DotMinus()
            if needgrad(x)
                δx = δ(z)
                x ← unbcast(δx, ᵛ(x))
            end
            if needgrad(y)
                δy = - δ(z)
                y ← unbcast(δy, ᵛ(y))
            end
        end
        addchild(z, x)
        addchild(z, y)
    end
    return z
end


function broadcasted(::typeof(-), x::Variable{T}, y::TensorOrReal) where T
    samesize(x, y) && return (x - y)

    z = Variable{T}(ᵛ(x) .- y, x.backprop)
    if z.backprop
        z.backward = function ∇DotMinus()
            if needgrad(x)
                x ← unbcast(δ(z), ᵛ(x))
            end
        end
        addchild(z, x)
    end
    return z
end


function broadcasted(::typeof(-), x::TensorOrReal, y::Variable{T}) where T
    samesize(x, y) && return (x - y)

    z = Variable{T}(x .- ᵛ(y), y.backprop)
    if z.backprop
        z.backward = function ∇DotMinus()
            if needgrad(y)
                δy = - δ(z)
                y ← unbcast(δy, ᵛ(y))
            end
        end
        addchild(z, y)
    end
    return z
end


# z = x .* y
function broadcasted(::typeof(*), x::Variable{T1}, y::Variable{T2}) where {T1,T2}
    samesize(x, y) && return emul(x, y)

    T = vartype(T1, T2)
    z = Variable{T}(ᵛ(x) .* ᵛ(y), x.backprop || y.backprop)
    if z.backprop
        z.backward = function ∇DotMul()
            if needgrad(x)
                δx = δ(z) .* ᵛ(y)
                x ← unbcast(δx, ᵛ(x))
            end
            if needgrad(y)
                δy = δ(z) .* ᵛ(x)
                y ← unbcast(δy, ᵛ(y))
            end
        end
        addchild(z, x)
        addchild(z, y)
    end
    return z
end


function broadcasted(::typeof(*), x::Variable{T}, y::TensorOrReal) where T
    samesize(x, y) && return emul(x, y)

    z = Variable{T}(ᵛ(x) .* y, x.backprop)
    if z.backprop
        z.backward = function ∇DotMul()
            if needgrad(x)
                δx = δ(z) .* y
                x ← unbcast(δx, ᵛ(x))
            end
        end
        addchild(z, x)
    end
    return z
end


function broadcasted(::typeof(*), x::TensorOrReal, y::Variable{T}) where T
    samesize(x, y) && return emul(x, y)

    z = Variable{T}(x .* ᵛ(y), y.backprop)
    if z.backprop
        z.backward = function ∇DotMul()
            if needgrad(y)
                δy = δ(z) .* x
                y ← unbcast(δy, ᵛ(y))
            end
        end
        addchild(z, y)
    end
    return z
end


# z = x ./ y
function broadcasted(::typeof(/), x::Variable{T1}, y::Variable{T2}) where {T1,T2}
    samesize(x, y) && return ediv(x, y)

    T = vartype(T1, T2)
    z = Variable{T}(ᵛ(x) ./ ᵛ(y), x.backprop || y.backprop)
    if z.backprop
        z.backward = function ∇DotDiv()
            δx = δ(z) ./ ᵛ(y)
            if needgrad(x)
                x ← unbcast(δx, ᵛ(x))
            end
            if needgrad(y)
                δy = - δx .* ᵛ(z)
                y ← unbcast(δy, ᵛ(y))
            end
        end
        addchild(z, x)
        addchild(z, y)
    end
    return z
end


function broadcasted(::typeof(/), x::Variable{T}, y::TensorOrReal) where T
    samesize(x, y) && return ediv(x, y)

    z = Variable{T}(ᵛ(x) ./ y, x.backprop)
    if z.backprop
        z.backward = function ∇DotDiv()
            if needgrad(x)
                δx = δ(z) ./ y
                x ← unbcast(δx, ᵛ(x))
            end
        end
        addchild(z, x)
    end
    return z
end


function broadcasted(::typeof(/), x::TensorOrReal, y::Variable{T}) where T
    samesize(x, y) && return ediv(x, y)

    z = Variable{T}(x ./ ᵛ(y), y.backprop)
    if z.backprop
        z.backward = function ∇DotDiv()
            if needgrad(y)
                δy = - δ(z) ./ ᵛ(y) .* ᵛ(z)
                y ← unbcast(δy, ᵛ(y))
            end
        end
        addchild(z, y)
    end
    return z
end

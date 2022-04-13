"""
# Summary ScalePath
    mutable struct ScalePath <: Scaler
# Fields
    scale::VarOrNil
Applies scalar multiplication over a N-dimensional input.
This `scale` is a learnable parameter.
# Example
If the `input` has size (C,H,W,B), then you should use :

`ScaleChannels(xxx; ndims=4)` and size(`scale`)==(1,1,1,1)

"""
mutable struct ScalePath <: Scaler
    scale::VarOrNil
    function ScalePath(scalar::AbstractFloat; ndims::Int, type::Type=Array{Float32})
        @assert ndims >= 1 "ndims >= 1 shall be met, but got ndims=$ndims"
        shape = ntuple(i->1, ndims)
        scale = Variable{type}(Zeros(type, shape) .+ eltype(type)(scalar), true, true, true);
        new(scale)
    end
    function ScalePath()
        new(nothing)
    end
end


function clone(this::ScalePath; type::Type=Array{Float32})
    cloned = ScalePath()
    cloned.scale = clone(this.scale, type=type)
    return cloned
end

function Base.show(io::IO, m::ScalePath)
    print(io, "ScalePath(scale=$(m.scale.value[1]); type=$(typeof(m.scale.value)))")
end

function paramsof(m::ScalePath)
    params = Vector{Variable}(undef,1)
    params[1] = m.scale
    return params
end

function xparamsof(m::ScalePath)
    xparams = Vector{XVariable}(undef,1)
    xparams[1] = ('w', m.scale)
    return xparams
end

function nparamsof(m::ScalePath)
    return 1
end

function bytesof(m::ScalePath, unit::String="MB")
    return blocksize(sizeof(m.scale), uppercase(unit))
end


function forward(m::ScalePath, x::Variable{T}) where T
    k = m.scale
    y = Variable{T}(ᵛ(x) .* ᵛ(k), x.backprop)

    if y.backprop
        y.backward = function ScalePathBackward()
            if need2computeδ!(x) δ(x) .+=     δ(y) .* ᵛ(k)  end
            if need2computeδ!(k) δ(k) .+= sum(δ(y) .* ᵛ(x)) end
            ifNotKeepδThenFreeδ!(y);
        end
        addchild(y, x)
        addchild(y, k)
    end
    return y
end


function predict(m::ScalePath, x::AbstractArray)
    k = ᵛ(m.scale)
    return ᵛ(x) .* k
end

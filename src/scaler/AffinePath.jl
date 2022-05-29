"""
# Summary AffinePath
    mutable struct AffinePath <: Scaler
# Fields
    scale :: VarOrNil
    bias  :: VarOrNil
Applies scalar multiplication and scalar bias over a N-dimensional input, i.e.
`x -> k .* x .+ b`
# Example
If the `input` has size (C,H,W,B), then you should use :

`AffinePath(xxx; ndims=4)` and size(`scale`)==(1,1,1,1)

"""
mutable struct AffinePath <: Scaler
    scale::VarOrNil
    bias::VarOrNil
    function AffinePath(k::Real, b::Real; ndims::Int, type::Type=Array{Float32})
        @assert ndims >= 1 "ndims >= 1 shall be met, but got ndims=$ndims"
        shape = ntuple(i->1, ndims)
        scale = Variable{type}(Zeros(type, shape) .+ eltype(type)(k), true, true, true);
        bias  = Variable{type}(Zeros(type, shape) .+ eltype(type)(b), true, true, true);
        new(scale, bias)
    end
    function AffinePath()
        new(nothing, nothing)
    end
end


function clone(this::AffinePath; type::Type=Array{Float32})
    cloned = AffinePath()
    cloned.scale = clone(this.scale, type=type)
    cloned.bias  = clone(this.bias,  type=type)
    return cloned
end

function Base.show(io::IO, m::AffinePath)
    k = Array(m.scale.value)[1]
    b = Array(m.bias.value)[1]
    print(io, "AffinePath(scale=$k, bias=$b; type=$(typeof(m.scale.value)))")
end

function paramsof(m::AffinePath)
    params = Vector{Variable}(undef,2)
    params[1] = m.scale
    params[2] = m.bias
    return params
end

function xparamsof(m::AffinePath)
    xparams = Vector{XVariable}(undef,2)
    xparams[1] = ('w', m.scale)
    xparams[2] = ('b', m.bias)
    return xparams
end

function nparamsof(m::AffinePath)
    return 2
end

elsizeof(a::AffinePath) = elsizeof(a.scale)

function bytesof(m::AffinePath, unit::String="MB")
    return blocksize(2*sizeof(m.scale), uppercase(unit))
end

nops(a::AffinePath) = (0, 0, 0)

function forward(m::AffinePath, x::Variable{T}) where T
    k = m.scale
    b = m.bias
    y = Variable{T}(ᵛ(k) .* ᵛ(x) .+ ᵛ(b), x.backprop)

    if y.backprop
        y.backward = function ∇ScalePath()
            if need2computeδ!(x) δ(x) .+=     δ(y) .* ᵛ(k)  end
            if need2computeδ!(k) δ(k) .+= sum(δ(y) .* ᵛ(x)) end
            if need2computeδ!(b) δ(b) .+= sum(δ(y)        ) end
            ifNotKeepδThenFreeδ!(y)
        end
        addchild(y, x)
        addchild(y, k)
        addchild(y, b)
    end
    return y
end


function predict(m::AffinePath, x::AbstractArray)
    k = ᵛ(m.scale)
    b = ᵛ(m.bias)
    return k .* x .+ b
end

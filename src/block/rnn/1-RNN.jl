"""
    RNN(isize::Int, hsize::Int, fn::FunOrNil=relu; type::Type=Array{Float32})
# Math
Vanilla RNN, i.e. ⤦\n
    h[t] = f(w * x[t] + u * h[t-1] .+ b)
"""
mutable struct RNN <: Block
    w::VarOrNil # input to hidden weights
    b::VarOrNil # bias of hidden units
    u::VarOrNil # recurrent weights
    f::FunOrNil # activation function
    h::Hidden   # hidden variable
    function RNN(isize::Int, hsize::Int, fn::FunOrNil=relu; type::Type=Array{Float32})
        T = eltype(type)
        λ = sqrt(T(2 / isize))
        β = T(0.1)

        w = randn(T, hsize, isize) .* λ
        b = zeros(T, hsize, 1)
        u = randdiagonal(T, hsize; from=-β, to=β)
        new(Variable{type}(w,true,true,true),
            Variable{type}(b,true,true,true),
            Variable{type}(u,true,true,true), fn, nothing)
    end
    function RNN(fn::FunOrNil)
        new(nothing, nothing, nothing, fn, nothing)
    end
end


function clone(this::RNN; type::Type=Array{Float32})
    cloned = RNN(this.f)
    cloned.w = clone(this.w, type=type)
    cloned.b = clone(this.b, type=type)
    cloned.u = clone(this.u, type=type)
    return cloned
end


mutable struct RNNs <: Block
    layers::Vector{RNN}
    function RNNs(topology::Vector{Int}, fn::Array{F}; type::Type=Array{Float32}) where F
        n = length(topology) - 1
        layers = Vector{RNN}(undef, n)
        for i = 1:n
            layers[i] = RNN(topology[i], topology[i+1], fn[i]; type=type)
        end
        new(layers)
    end
end


Base.getindex(m::RNNs,     k...) =  m.layers[k...]
Base.setindex!(m::RNNs, v, k...) = (m.layers[k...] = v)
Base.length(m::RNNs)       = length(m.layers)
Base.lastindex(m::RNNs)    = length(m.layers)
Base.firstindex(m::RNNs)   = 1
Base.iterate(m::RNNs, i=firstindex(m)) = i>length(m) ? nothing : (m[i], i+1)


function Base.show(io::IO, m::RNN)
    SIZE = size(m.w)
    TYPE = typeof(m.w.value)
    print(io, "RNN($(SIZE[2]), $(SIZE[1]), $(m.f); type=$TYPE)")
end


function Base.show(io::IO, m::RNNs)
    print(io, "RNNs\n      (\n          ")
    join(io, m.layers, ",\n          ")
    print(io, "\n      )")
end

function fan_in_out(m::RNN)
    SIZE = size(m.w)
    ochs = SIZE[1]
    ichs = SIZE[2]
    return ichs, ochs
end

function fanin(m::RNN)
    SIZE = size(m.w)
    ichs = SIZE[2]
    return ichs
end

function fanout(m::RNN)
    SIZE = size(m.w)
    ochs = SIZE[1]
    return ochs
end

function resethidden(m::RNN)
    m.h = nothing
end


function resethidden(model::RNNs)
    for m in model
        resethidden(m)
    end
end


function forward(m::RNN, x::Variable{T}) where T
    f = m.f  # activition function
    w = m.w  # input's weights
    b = m.b  # input's bias
    u = m.u  # memory's weights
    h = !isnothing(m.h) ? m.h : Variable(Zeros(T, size(w,1), size(x,2)), type=T)
    uh = nothing
    wx = nothing
    @sync begin
        Threads.@spawn uh = u * h
        Threads.@spawn wx = w * x
    end
    x = f(addmv(wx + uh, b))
    m.h = x
    return x
end


function forward(model::RNNs, x::Variable)
    for m in model
        x = forward(m, x)
    end
    return x
end


function predict(m::RNN, x::T) where T
    f = m.f        # activition function
    w = m.w.value  # input's weights
    b = m.b.value  # input's bias
    u = m.u.value  # memory's weights
    h = m.h ≠ nothing ? m.h : Zeros(T, size(w,1), size(x,2))
    uh = nothing
    wx = nothing
    @sync begin
        Threads.@spawn uh = u * h
        Threads.@spawn wx = w * x
    end
    x = f(wx + uh .+ b)
    m.h = x
    return x
end


function predict(model::RNNs, x)
    for m in model
        x = predict(m, x)
    end
    return x
end


"""
    unbiasedof(m::RNN)

unbiased weights of RNN block
"""
function unbiasedof(m::RNN)
    weights = Vector(undef, 1)
    weights[1] = m.w.value
    return weights
end


function weightsof(m::RNN)
    weights = Vector(undef,3)
    weights[1] = m.w.value
    weights[2] = m.b.value
    weights[3] = m.u.value
    return weights
end


"""
    unbiasedof(model::RNNs)

unbiased weights of RNNs block
"""
function unbiasedof(model::RNNs)
    weights = Vector(undef, 0)
    for m in model
        append!(weights, unbiasedof(m))
    end
    return weights
end


function weightsof(m::RNNs)
    weights = Vector(undef,0)
    for i = 1:length(m)
        append!(weights, weightsof(m[i]))
    end
    return weights
end


function gradsof(m::RNN)
    grads = Vector(undef,3)
    grads[1] = m.w.delta
    grads[2] = m.b.delta
    grads[3] = m.u.delta
    return grads
end


function gradsof(m::RNNs)
    grads = Vector(undef,0)
    for i = 1:length(m)
        append!(grads, gradsof(m[i]))
    end
    return grads
end


function zerograds!(m::RNN)
    for v in gradsof(m)
        v .= zero(v)
    end
end


function zerograds!(m::RNNs)
    for v in gradsof(m)
        v .= zero(v)
    end
end


function paramsof(m::RNN)
    params = Vector{Variable}(undef,3)
    params[1] = m.w
    params[2] = m.b
    params[3] = m.u
    return params
end


function xparamsof(m::RNN)
    xparams = Vector{XVariable}(undef,3)
    xparams[1] = ('w', m.w)
    xparams[2] = ('b', m.b)
    xparams[3] = ('u', m.u)
    return xparams
end


function paramsof(m::RNNs)
    params = Vector{Variable}(undef,0)
    for i = 1:length(m)
        append!(params, paramsof(m[i]))
    end
    return params
end


function xparamsof(m::RNNs)
    xparams = Vector{XVariable}(undef,0)
    for i = 1:length(m)
        append!(xparams, xparamsof(m[i]))
    end
    return xparams
end


function nparamsof(m::RNN)
    lw = length(m.w)
    lb = length(m.b)
    lu = length(m.u)
    return (lw + lb + lu)
end


function bytesof(model::RNN, unit::String="MB")
    n = nparamsof(model) * elsizeof(model.w)
    return blocksize(n, uppercase(unit))
end


function nparamsof(m::RNNs)
    num = 0
    for i = 1:length(m)
        num += nparamsof(m[i])
    end
    return num
end


function bytesof(model::RNNs, unit::String="MB")
    n = nparamsof(model) * elsizeof(model[1].w)
    return blocksize(n, uppercase(unit))
end


function to(type::Type, m::RNN)
    m.w = to(type, m.w)
    m.b = to(type, m.b)
    m.u = to(type, m.u)
    return m
end


function to!(type::Type, m::RNN)
    m = to(type, m)
    return nothing
end


function to(type::Type, m::RNNs)
    for layer in m
        layer = to(type, layer)
    end
    return m
end


function to!(type::Type, m::RNNs)
    for layer in m
        to!(type, layer)
    end
end


function nops(rnn::RNN, c::Int=1)
    m, n = size(rnn.w)
    mops = m * n + m * m
    aops = m * (n-1) + m * (m-1) + 2*m
    acts = m
    return (mops, aops, acts) .* c
end


function nops(rnns::RNNs, c::Int=1)
    mops, aops, acts = 0, 0, 0
    for m in rnns
        mo, ao, ac = nops(m, c)
        mops += mo
        aops += ao
        acts += ac
    end
    return (mops, aops, acts)
end

elsizeof(r::RNN) = elsizeof(r.w)

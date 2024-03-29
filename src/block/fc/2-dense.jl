"""
    mutable struct Dense <: Block

Applies y = fn(w * x .+ b) transformation to the incoming data x
"""
mutable struct Dense <: Block
    w::VarOrNil
    b::VarOrNil
    f::Function
    function Dense(isize::Int, hsize::Int, fn::Function=relu; type::Type=Array{Float32})
        T = eltype(type)
        A = T(sqrt(2 / isize))
        w = randn(T, hsize, isize) .* A
        b = randn(T, hsize,     1) .* A
        new(Variable{type}(w,true,true,true), Variable{type}(b,true,true,true), fn)
    end
    function Dense(fn::Function)
        new(nothing, nothing, fn)
    end
end


function clone(this::Dense; type::Type=Array{Float32})
    cloned = Dense(this.f)
    cloned.w = clone(this.w, type=type)
    cloned.b = clone(this.b, type=type)
    return cloned
end


# pretty show
function Base.show(io::IO, m::Dense)
    SIZE = size(m.w)
    TYPE = typeof(m.w.value)
    print(io, "Dense($(SIZE[2]), $(SIZE[1]), $(m.f); type=$TYPE)")
end



function fan_in_out(d::Dense)
    SIZE = size(d.w)
    ochs = SIZE[1]
    ichs = SIZE[2]
    return ichs, ochs
end

function fanin(d::Dense)
    SIZE = size(d.w)
    ichs = SIZE[2]
    return ichs
end

function fanout(d::Dense)
    SIZE = size(d.w)
    ochs = SIZE[1]
    return ochs
end


mutable struct MLP <: Block
    layers::Vector{Dense}
    function MLP(topology::Vector{Int}; type::Type=Array{Float32})
        n = length(topology) - 1
        layers = Vector{Dense}(undef, n)
        for i = 1:n
            layers[i] = Dense(topology[i], topology[i+1], relu; type=type)
        end
        new(layers)
    end

    function MLP(topology::Vector{Int}, fn::Vector{F}; type::Type=Array{Float32}) where F
        n = length(topology) - 1
        layers = Vector{Dense}(undef, n)
        for i = 1:n
            layers[i] = Dense(topology[i], topology[i+1], fn[i]; type=type)
        end
        new(layers)
    end
end


# pretty show
function Base.show(io::IO, m::MLP)
    print(io, "MLP\n      (\n          ")
    join(io,    m.layers, "\n          ")
    print(io,                "\n      )")
end


Base.length(m::MLP)             = length(m.layers)
Base.lastindex(m::MLP)          = length(m.layers)
Base.getindex(m::MLP, k...)     =        m.layers[k...]
Base.setindex!(m::MLP, v, k...) =       (m.layers[k...] = v)
Base.firstindex(m::MLP) = 1
Base.iterate(m::MLP, i=firstindex(m)) = i>length(m) ? nothing : (m[i], i+1)


function forward(m::Dense, x::Variable)
    f = m.f
    w = m.w
    b = m.b
    return f( addmv(w*x, b) )
end


function forward(m::MLP, x::Variable)
    for i = 1:length(m)
        x = forward(m[i], x)
    end
    return x
end


function predict(m::Dense, x)
    f = m.f
    w = m.w.value
    b = m.b.value
    return f(w * x .+ b)
end


function predict(m::MLP, x)
    for i = 1:length(m)
        x = predict(m[i], x)
    end
    return x
end


"""
    unbiasedof(m::Dense)

unbiased weights of Dense block
"""
function unbiasedof(m::Dense)
    weights = Vector(undef, 1)
    weights[1] = m.w.value
    return weights
end


function weightsof(m::Dense)
    weights = Vector(undef, 2)
    weights[1] = m.w.value
    weights[2] = m.b.value
    return weights
end


"""
    unbiasedof(m::MLP)

unbiased weights of MLP block
"""
function unbiasedof(m::MLP)
    weights = Vector(undef,0)
    for i = 1:length(m)
        append!(weights, unbiasedof(m[i]))
    end
    return weights
end


function weightsof(m::MLP)
    weights = Vector(undef,0)
    for i = 1:length(m)
        append!(weights, weightsof(m[i]))
    end
    return weights
end


function gradsof(m::Dense)
    grads = Vector(undef, 2)
    grads[1] = m.w.delta
    grads[2] = m.b.delta
    return grads
end


function gradsof(m::MLP)
    grads = Vector(undef,0)
    for i = 1:length(m)
        append!(grads, gradsof(m[i]))
    end
    return grads
end


function zerograds!(m::Dense)
    for v in gradsof(m)
        v .= 0.0
    end
end


function zerograds!(m::MLP)
    for v in gradsof(m)
        v .= 0.0
    end
end


function paramsof(m::Dense)
    params = Vector{Variable}(undef,2)
    params[1] = m.w
    params[2] = m.b
    return params
end


function xparamsof(m::Dense)
    xparams = Vector{XVariable}(undef,2)
    xparams[1] = ('w', m.w)
    xparams[2] = ('b', m.b)
    return xparams
end


function paramsof(m::MLP)
    params = Vector{Variable}(undef,0)
    for i = 1:length(m)
        append!(params, paramsof(m[i]))
    end
    return params
end


function xparamsof(m::MLP)
    params = Vector{XVariable}(undef,0)
    for i = 1:length(m)
        append!(params, xparamsof(m[i]))
    end
    return params
end


function nparamsof(m::Dense)
    lw = length(m.w)
    lb = length(m.b)
    return (lw + lb)
end

elsizeof(d::Dense) = elsizeof(d.w)

function bytesof(model::Dense, unit::String="MB")
    n = nparamsof(model) * elsizeof(model)
    return blocksize(n, uppercase(unit))
end


function nparamsof(m::MLP)
    num = 0
    for i = 1:length(m)
        num += nparamsof(m[i])
    end
    return num
end

elsizeof(m::MLP) = elsizeof(m[1].w)

function bytesof(model::MLP, unit::String="MB")
    n = nparamsof(model) * elsizeof(model)
    return blocksize(n, uppercase(unit))
end

function to(type::Type, m::Dense)
    m.w = to(type, m.w)
    m.b = to(type, m.b)
    return m
end


function to!(type::Type, m::Dense)
    m.w = to(type, m.w)
    m.b = to(type, m.b)
    return nothing
end


function to(type::Type, m::MLP)
    for layer in m
        layer = to(type, layer)
    end
    return m
end


function to!(type::Type, m::MLP)
    for layer in m
        to!(type, layer)
    end
end


function nops(d::Dense, c::Int=1)
    m, n = size(d.w)
    mops = m * n            # mul ops
    aops = m * (n-1) + m    # add ops
    acts = m                # active ops
    return (mops, aops, acts) .* c
end

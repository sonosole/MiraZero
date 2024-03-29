"""
    mutable struct Linear <: Block

Applies a linear transformation to the incoming data: y = w * x .+ b
"""
mutable struct Linear <: Block
    w::VarOrNil # input to hidden weights
    b::VarOrNil # bias of hidden units
    function Linear(isize::Int, hsize::Int; type::Type=Array{Float32})
        T = eltype(type)
        A = T(sqrt(1 / isize))
        w = randn(T, hsize, isize) .* A
        b = randn(T, hsize,     1) .* A
        new(Variable{type}(w,true,true,true),
            Variable{type}(b,true,true,true))
    end
    function Linear()
        new(nothing, nothing)
    end
end


function clone(this::Linear; type::Type=Array{Float32})
    cloned = Linear()
    cloned.w = clone(this.w, type=type)
    cloned.b = clone(this.b, type=type)
    return cloned
end


# pretty show
function Base.show(io::IO, m::Linear)
    SIZE = size(m.w)
    TYPE = typeof(m.w.value)
    print(io, "Linear($(SIZE[2]), $(SIZE[1]); type=$TYPE)")
end

function fan_in_out(l::Linear)
    SIZE = size(l.w)
    ochs = SIZE[1]
    ichs = SIZE[2]
    return ichs, ochs
end

function fanin(l::Linear)
    SIZE = size(l.w)
    ichs = SIZE[2]
    return ichs
end

function fanout(l::Linear)
    SIZE = size(l.w)
    ochs = SIZE[1]
    return ochs
end


"""
    unbiasedof(m::Linear)

unbiased weights of `Linear` block
"""
function unbiasedof(m::Linear)
    weights = Vector(undef, 1)
    weights[1] = m.w.value
    return weights
end

function weightsof(m::Linear)
    weights = Vector(undef, 2)
    weights[1] = m.w.value
    weights[2] = m.b.value
    return weights
end


function gradsof(m::Linear)
    grads = Vector(undef, 2)
    grads[1] = m.w.delta
    grads[2] = m.b.delta
    return grads
end


function zerograds!(m::Linear)
    for v in gradsof(m)
        v .= 0.0
    end
end


function paramsof(m::Linear)
    params = Vector{Variable}(undef,2)
    params[1] = m.w
    params[2] = m.b
    return params
end


function xparamsof(m::Linear)
    xparams = Vector{XVariable}(undef,2)
    xparams[1] = ('w', m.w)
    xparams[2] = ('b', m.b)
    return xparams
end


function nparamsof(m::Linear)
    lw = length(m.w)
    lb = length(m.b)
    return (lw + lb)
end

elsizeof(l::Linear) = elsizeof(l.w)

function bytesof(model::Linear, unit::String="MB")
    n = nparamsof(model) * elsizeof(model)
    return blocksize(n, uppercase(unit))
end


function forward(m::Linear, x::Variable)
    w = m.w
    b = m.b
    return addmv(w * x, b)
end


function predict(m::Linear, x)
    w = m.w.value
    b = m.b.value
    return (w * x .+ b)
end


function to(type::Type, m::Linear)
    m.w = to(type, m.w)
    m.b = to(type, m.b)
    return m
end


function to!(type::Type, m::Linear)
    m.w = to(type, m.w)
    m.b = to(type, m.b)
    return nothing
end


function nops(l::Linear, c::Int=1)
    m, n = size(l.w)
    mops = m * n            # mul ops
    aops = m * (n-1) + m    # add ops
    acts = 0                # active ops
    return (mops, aops, acts) .* c
end

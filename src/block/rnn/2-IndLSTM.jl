"""
    IndLSTM(isize::Int, hsize::Int; type::Type=Array{Float32})
# Math
    z = tanh(    wc * x + uc .* h .+ bc )
    i = sigmoid( wi * x + ui .* h .+ bi )
    f = sigmoid( wf * x + uf .* h .+ bf )
    o = sigmoid( wo * x + uo .* h .+ bo )
    c = f .* c + i .* z
    h = o .* tanh(c)
"""
mutable struct IndLSTM <: Block
    # input control gate params
    wi::VarOrNil
    ui::VarOrNil
    bi::VarOrNil
    # forget control gate params
    wf::VarOrNil
    uf::VarOrNil
    bf::VarOrNil
    # out control gate params
    wo::VarOrNil
    uo::VarOrNil
    bo::VarOrNil
    # new cell info params
    wc::VarOrNil
    uc::VarOrNil
    bc::VarOrNil
    # hidden and cell states
    h::Hidden
    c::Hidden
    function IndLSTM(isize::Int, hsize::Int; type::Type=Array{Float32})
        T  = eltype(type)
        λ  = sqrt(T(1/isize))
        β  = T(0.1)

        wi = randn(T, hsize, isize) .* λ
        ui = randn(T, hsize, 1) .* β
        bi = zeros(T, hsize, 1)

        wf = randn(T, hsize, isize) .* λ
        uf = randn(T, hsize, 1) .* β
        bf = zeros(T, hsize, 1) .+ T(1)

        wo = randn(T, hsize, isize) .* λ
        uo = randn(T, hsize, 1) .* β
        bo = zeros(T, hsize, 1)

        wc = randn(T, hsize, isize) .* λ
        uc = randn(T, hsize, 1) .* β
        bc = zeros(T, hsize, 1)

        new(Variable{type}(wi,true,true,true), Variable{type}(ui,true,true,true), Variable{type}(bi,true,true,true),
            Variable{type}(wf,true,true,true), Variable{type}(uf,true,true,true), Variable{type}(bf,true,true,true),
            Variable{type}(wo,true,true,true), Variable{type}(uo,true,true,true), Variable{type}(bo,true,true,true),
            Variable{type}(wc,true,true,true), Variable{type}(uc,true,true,true), Variable{type}(bc,true,true,true), nothing, nothing)
    end
    function IndLSTM()
        new(nothing, nothing, nothing,
            nothing, nothing, nothing,
            nothing, nothing, nothing,
            nothing, nothing, nothing, nothing, nothing)
    end
end


function clone(this::IndLSTM; type::Type=Array{Float32})
    cloned = IndLSTM()

    cloned.wi = clone(this.wi, type=type)
    cloned.bi = clone(this.bi, type=type)
    cloned.ui = clone(this.ui, type=type)

    cloned.wf = clone(this.wf, type=type)
    cloned.bf = clone(this.bf, type=type)
    cloned.uf = clone(this.uf, type=type)

    cloned.wo = clone(this.wo, type=type)
    cloned.bo = clone(this.bo, type=type)
    cloned.uo = clone(this.uo, type=type)

    cloned.wc = clone(this.wc, type=type)
    cloned.bc = clone(this.bc, type=type)
    cloned.uc = clone(this.uc, type=type)

    return cloned
end


mutable struct IndLSTMs <: Block
    layers::Vector{IndLSTM}
    function IndLSTMs(topology::Vector{Int}; type::Type=Array{Float32})
        n = length(topology) - 1
        layers = Vector{IndLSTM}(undef, n)
        for i = 1:n
            layers[i] = IndLSTM(topology[i], topology[i+1]; type=type)
        end
        new(layers)
    end
end


Base.getindex(m::IndLSTMs,     k...) =  m.layers[k...]
Base.setindex!(m::IndLSTMs, v, k...) = (m.layers[k...] = v)
Base.length(m::IndLSTMs)       = length(m.layers)
Base.lastindex(m::IndLSTMs)    = length(m.layers)
Base.firstindex(m::IndLSTMs)   = 1
Base.iterate(m::IndLSTMs, i=firstindex(m)) = i>length(m) ? nothing : (m[i], i+1)

function fan_in_out(m::IndLSTM)
    SIZE = size(m.wi)
    ochs = SIZE[1]
    ichs = SIZE[2]
    return ichs, ochs
end

function fanin(m::IndLSTM)
    SIZE = size(m.wi)
    ichs = SIZE[2]
    return ichs
end

function fanout(m::IndLSTM)
    SIZE = size(m.wi)
    ochs = SIZE[1]
    return ochs
end

function Base.show(io::IO, m::IndLSTM)
    SIZE = size(m.wi)
    TYPE = typeof(m.wi.value)
    print(io, "IndLSTM($(SIZE[2]), $(SIZE[1]); type=$TYPE)")
end


function Base.show(io::IO, model::IndLSTMs)
    for m in model
        show(io, m)
    end
end


function resethidden(model::IndLSTM)
    model.h = nothing
    model.c = nothing
end


function resethidden(model::IndLSTMs)
    for m in model
        resethidden(m)
    end
end


function forward(model::IndLSTM, x::Variable{T}) where T
    wi = model.wi
    ui = model.ui
    bi = model.bi

    wf = model.wf
    uf = model.uf
    bf = model.bf

    wo = model.wo
    uo = model.uo
    bo = model.bo

    wc = model.wc
    uc = model.uc
    bc = model.bc

    h = !isnothing(model.h) ? model.h : Variable(Zeros(T, size(wi,1), size(x,2)), type=T)
    c = !isnothing(model.c) ? model.c : Variable(Zeros(T, size(wc,1), size(x,2)), type=T)

    WcX, WiX, WfX, WoX = nothing,nothing,nothing,nothing
    UcH, UiH, UfH, UoH = nothing,nothing,nothing,nothing
    z,  i,  f,  o      = nothing,nothing,nothing,nothing
    @sync begin
        Threads.@spawn WcX = wc * x
        Threads.@spawn WiX = wi * x
        Threads.@spawn WfX = wf * x
        Threads.@spawn WoX = wo * x
        Threads.@spawn UcH = uc .* h
        Threads.@spawn UiH = ui .* h
        Threads.@spawn UfH = uf .* h
        Threads.@spawn UoH = uo .* h
    end
    @sync begin
        Threads.@spawn z = tanh(    WcX + UcH .+ bc )
        Threads.@spawn i = sigmoid( WiX + UiH .+ bi )
        Threads.@spawn f = sigmoid( WfX + UfH .+ bf )
        Threads.@spawn o = sigmoid( WoX + UoH .+ bo )
    end
    @sync begin
        Threads.@spawn c = f .* c + i .* z
        Threads.@spawn h = o .* tanh(c)
    end
    model.c = c
    model.h = h
    return h
end


function forward(model::IndLSTMs, x::Variable)
    for m in model
        x = forward(m, x)
    end
    return x
end


function predict(model::IndLSTM, x::T) where T
    wi = ᵛ(model.wi)
    ui = ᵛ(model.ui)
    bi = ᵛ(model.bi)

    wf = ᵛ(model.wf)
    uf = ᵛ(model.uf)
    bf = ᵛ(model.bf)

    wo = ᵛ(model.wo)
    uo = ᵛ(model.uo)
    bo = ᵛ(model.bo)

    wc = ᵛ(model.wc)
    uc = ᵛ(model.uc)
    bc = ᵛ(model.bc)

    h = model.h ≠ nothing ? model.h : Zeros(T, size(wi,1), size(x,2))
    c = model.c ≠ nothing ? model.c : Zeros(T, size(wc,1), size(x,2))

    WcX, WiX, WfX, WoX = nothing,nothing,nothing,nothing
    UcH, UiH, UfH, UoH = nothing,nothing,nothing,nothing
    z,  i,  f,  o      = nothing,nothing,nothing,nothing
    @sync begin
        Threads.@spawn WcX = wc * x
        Threads.@spawn WiX = wi * x
        Threads.@spawn WfX = wf * x
        Threads.@spawn WoX = wo * x
        Threads.@spawn UcH = uc .* h
        Threads.@spawn UiH = ui .* h
        Threads.@spawn UfH = uf .* h
        Threads.@spawn UoH = uo .* h
    end
    @sync begin
        Threads.@spawn z = tanh(    WcX + UcH .+ bc )
        Threads.@spawn i = sigmoid( WiX + UiH .+ bi )
        Threads.@spawn f = sigmoid( WfX + UfH .+ bf )
        Threads.@spawn o = sigmoid( WoX + UoH .+ bo )
    end
    @sync begin
        Threads.@spawn c = f .* c + i .* z
        Threads.@spawn h = o .* tanh(c)
    end

    model.c = c
    model.h = h

    return h
end


function predict(model::IndLSTMs, x)
    for m in model
        x = predict(m, x)
    end
    return x
end


"""
    unbiasedof(m::IndLSTM)

unbiased weights of IndLSTM block
"""
function unbiasedof(m::IndLSTM)
    weights = Vector(undef, 4)
    weights[1] = m.wi.value
    weights[2] = m.wf.value
    weights[3] = m.wo.value
    weights[4] = m.wc.value
    return weights
end


function weightsof(m::IndLSTM)
    weights = Vector{Variable}(undef,12)
    weights[1] = m.wi.value
    weights[2] = m.ui.value
    weights[3] = m.bi.value

    weights[4] = m.wf.value
    weights[5] = m.uf.value
    weights[6] = m.bf.value

    weights[7] = m.wo.value
    weights[8] = m.uo.value
    weights[9] = m.bo.value

    weights[10] = m.wc.value
    weights[11] = m.uc.value
    weights[12] = m.bc.value
    return weights
end


"""
    unbiasedof(model::IndLSTMs)

unbiased weights of IndLSTMs block
"""
function unbiasedof(model::IndLSTMs)
    weights = Vector(undef, 0)
    for m in model
        append!(weights, unbiasedof(m))
    end
    return weights
end


function weightsof(model::IndLSTMs)
    weights = Vector(undef,0)
    for m in model
        append!(weights, weightsof(m))
    end
    return weights
end


function gradsof(m::IndLSTM)
    grads = Vector{Variable}(undef,12)
    grads[1] = m.wi.delta
    grads[2] = m.ui.delta
    grads[3] = m.bi.delta

    grads[4] = m.wf.delta
    grads[5] = m.uf.delta
    grads[6] = m.bf.delta

    grads[7] = m.wo.delta
    grads[8] = m.uo.delta
    grads[9] = m.bo.delta

    grads[10] = m.wc.delta
    grads[11] = m.uc.delta
    grads[12] = m.bc.delta
    return grads
end


function gradsof(model::IndLSTMs)
    grads = Vector(undef,0)
    for m in model
        append!(grads, gradsof(m))
    end
    return grads
end


function zerograds!(m::IndLSTM)
    for v in gradsof(m)
        v .= zero(v)
    end
end


function zerograds!(m::IndLSTMs)
    for v in gradsof(m)
        v .= zero(v)
    end
end


function paramsof(m::IndLSTM)
    params = Vector{Variable}(undef,12)
    params[1] = m.wi
    params[2] = m.ui
    params[3] = m.bi

    params[4] = m.wf
    params[5] = m.uf
    params[6] = m.bf

    params[7] = m.wo
    params[8] = m.uo
    params[9] = m.bo

    params[10] = m.wc
    params[11] = m.uc
    params[12] = m.bc
    return params
end


function xparamsof(m::IndLSTM)
    xparams = Vector{XVariable}(undef,12)
    xparams[1] = ('w', m.wi)
    xparams[2] = ('u', m.ui)
    xparams[3] = ('b', m.bi)

    xparams[4] = ('w', m.wf)
    xparams[5] = ('u', m.uf)
    xparams[6] = ('b', m.bf)

    xparams[7] = ('w', m.wo)
    xparams[8] = ('u', m.uo)
    xparams[9] = ('b', m.bo)

    xparams[10] = ('w', m.wc)
    xparams[11] = ('u', m.uc)
    xparams[12] = ('b', m.bc)
    return xparams
end


function paramsof(model::IndLSTMs)
    params = Vector{Variable}(undef,0)
    for m in model
        append!(params, paramsof(m))
    end
    return params
end


function xparamsof(model::IndLSTMs)
    xparams = Vector{XVariable}(undef,0)
    for m in model
        append!(xparams, xparamsof(m))
    end
    return xparams
end


function nparamsof(m::IndLSTM)
    lw = length(m.wi)
    lu = length(m.ui)
    lb = length(m.bi)
    return (lw+lu+lb)*4
end


function bytesof(model::IndLSTM, unit::String="MB")
    n = nparamsof(model) * elsizeof(model.wi)
    return blocksize(n, uppercase(unit))
end


function nparamsof(model::IndLSTMs)
    num = 0
    for m in model
        num += nparamsof(m)
    end
    return num
end


function bytesof(model::IndLSTMs, unit::String="MB")
    n = nparamsof(model) * elsizeof(model[1].wi)
    return blocksize(n, uppercase(unit))
end


function to(type::Type, m::IndLSTM)
    m.wi = to(type, m.wi)
    m.ui = to(type, m.ui)
    m.bi = to(type, m.bi)

    m.wf = to(type, m.wf)
    m.uf = to(type, m.uf)
    m.bf = to(type, m.bf)

    m.wo = to(type, m.wo)
    m.uo = to(type, m.uo)
    m.bo = to(type, m.bo)

    m.wc = to(type, m.wc)
    m.uc = to(type, m.uc)
    m.bc = to(type, m.bc)
    return m
end


function to!(type::Type, m::IndLSTM)
    m = to(type, m)
    return nothing
end


function to(type::Type, m::IndLSTMs)
    for layer in m
        layer = to(type, layer)
    end
    return m
end


function to!(type::Type, m::IndLSTMs)
    for layer in m
        to!(type, layer)
    end
end


elsizeof(i::IndLSTM) = elsizeof(i.wi)
elsizeof(i::IndLSTMs) = elsizeof(i[1].wi)


function nops(indlstm::IndLSTM, c::Int=1)
    m, n = size(indlstm.wi)
    mops = 4 * m * n + 7 * m
    aops = 4 * m * (n-1) + 9 * m
    acts = 5 * m
    return (mops, aops, acts) .* c
end


function nops(indlstms::IndLSTMs, c::Int=1)
    mops, aops, acts = 0, 0, 0
    for m in indlstms
        mo, ao, ac = nops(m, c)
        mops += mo
        aops += ao
        acts += ac
    end
    return (mops, aops, acts)
end

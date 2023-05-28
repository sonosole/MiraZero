export zerodelta
export clone
export need2computeδ!
export ifNotKeepδThenFreeδ!
export elsizeof
export value, delta, ᵛ, ᵟ, δ
export isleaf, setleaf, backprop, keepsgrad, needsgrad
export haschild, childrenof, addchild, nchildrenof
export haskid, kidsof, addkid, nkidsof

export isroot
export ismarked
export setmarked
export unsetmarked
export VecVariable
export VecXVariable

export Variable, Variables
export XVariable, XVariables
export VarOrNil


"""
    mutable struct Variable{T} where T <: AbstractArray

# Constructor
    function Variable{T}(x,
                         backprop  :: Bool=true,  # when forward, it's true
                         keepsgrad :: Bool=false, # whether keeps grad after backward
                         isleaf    :: Bool=false) # whether leaf node
"""
mutable struct Variable{T}
    value     :: T                   # value in forward
    delta     :: Union{Nothing,T}    # gradients collected in backprop
    shape     :: Tuple               # shape of `value`
    isleaf    :: Bool                # whether leaf node
    backprop  :: Bool                # whether needs backprop when forward
    keepsgrad :: Bool                # whether keeps grad after backprop
    ismarked  :: Bool                # whether marked during backprop
    indegree  :: Int                 # in backward view, the indegree of a node
    backward  :: FunOrNil            # backward function
    children  :: Vector{Variable{T}} # children Variables
    function Variable{T}(x, backprop  :: Bool=true,
                            keepsgrad :: Bool=false,
                            isleaf    :: Bool=false) where T <: AbstractArray
        delta    = nothing
        shape    = size(x)
        ismarked = false
        indegree = 0
        backward = nothing
        children = Vector{Variable{T}}()
        new{T}(x, delta, shape, isleaf, backprop, keepsgrad, ismarked, indegree, backward, children)
    end
end


# Convenient type-specilized constructors for data on GPU/CPU/xPU etc....
function Variable(x; backprop::Bool=true,
                     keepsgrad::Bool=false,
                     type::Type=Array{Float32})
    isleaf = true    # any user defined Variable is a leaf
    return Variable{type}(x, backprop, keepsgrad, isleaf)
end


const XVariable  = Tuple{Char, Variable}
const VarOrNil   = Union{Variable, Nothing}
const Variables  = Vector{Variable}
const XVariables = Vector{XVariable}

# pretty printing
function Base.show(io::IO, ::MIME"text/plain", x::Variable)
    if isleaf(x)
        prefix = " Leaf's"
    else
        prefix = " None Leaf's"
    end

    print(yellow!(prefix * " value is "))
    display(x.value)

    if !isnothing(δ(x))
        print(green!("\n" * prefix * " delta is "))
        display(x.delta)
    end
end

function infos(x::Variable)
    print("(")
    print("isleaf=$(x.isleaf|>colorbool), ")
    print("keepsgrad=$(x.keepsgrad|>colorbool), ")
    print("indegree=$(x.indegree), ")
    print("nkids=$(x.children|>length)")
    print(")")
end


function clone(x::Variable; type::Type=Array{Float32})
    return Variable{type}(x.value, x.backprop, x.keepsgrad, x.isleaf)
end


function clone(x::Nothing; type::Type=Array{Float32})
    return nothing
end

@inline Base.zero(x::Variable) = zero(x.value)

function zerodelta(x::Variable{T}) where T
    if isnothing(x.delta)
        x.delta = Zeros(T, x.shape);
    end
end

@inline Base.Broadcast.broadcasted(::typeof(+), n::Nothing, x::AbstractArray) = x

@inline Base.:(+)(n::Nothing, x::AbstractArray) = x

@inline function (←)(x::Variable, δx::AbstractArray)
    x.delta += δx
end
# @inline function (←)(x::Variable, δx::AbstractArray)
#     !isa(x.delta, AbstractArray) ? (x.delta = δx) : (x.delta += δx)
# end

function filldelta(x::Variable{T}, g::Union{Real,T}) where T
    if isnothing(x.delta)
        x.delta  = T(undef, size(x))
        x.delta .= g
    end
end

function need2computeδ!(x::Variable)
    # 1. 不需要学习的叶子参数不需要初始化，其他情况都要。
    # 2. 当某叶子节点的 keepsgrad==false 时，则此叶子节
    #   点不参与反向传播的计算，也即达到了冻结参数的目的
    if !(x.isleaf && !x.keepsgrad)
        # zerodelta(x)
        return true
    else
        return false
    end
end


function ifNotKeepδThenFreeδ!(x::Variable)
    if !x.keepsgrad
        x.delta = nothing
    end
end



Base.sizeof(x::Variable)         =  sizeof(x.value)
Base.size(x::Variable)           =    size(x.value)
Base.size(x::Variable, dim::Int) =    size(x.value, dim)
Base.ndims(x::Variable)          =   ndims(x.value)
Base.length(x::Variable)         =  length(x.value)
Base.strides(x::Variable)        = strides(x.value)
Base.eltype(x::Variable)         =  eltype(x.value)
Base.similar(x::Variable{T})  where T = Variable{T}( similar(x.value), x.backprop, x.keepsgrad, x.isleaf)
Base.copy(x::Variable{T})     where T = Variable{T}(    copy(x.value), x.backprop, x.keepsgrad, x.isleaf)
Base.deepcopy(x::Variable{T}) where T = Variable{T}(deepcopy(x.value), x.backprop, x.keepsgrad, x.isleaf)

Base.setindex!(x::Variable, v::Number,        k...) = (x.value[k...] .= v)
Base.setindex!(x::Variable, v::AbstractArray, k...) = (x.value[k...]  = v)



function Base.getindex(x::Variable{T}, k...) where T
    !x.backprop && return x.value[k...]
    y = Variable{T}(x.value[k...], x.backprop, x.keepsgrad, x.isleaf)
    if y.backprop
        y.backward = function ∇getindex()
            if need2computeδ!(x)
                x.delta[k...] .+= y.delta
            end
            ifNotKeepδThenFreeδ!(y)
        end
        addchild(y, x)
    end
    return y
end


function Base.getindex(x::Variable{T}, k::Int) where T
    !x.backprop && return x.value[k:k]
    y = Variable{T}(x.value[k:k], x.backprop, x.keepsgrad, x.isleaf)
    if y.backprop
        y.backward = function ∇getindex()
            if need2computeδ!(x)
                x.delta[k:k] .+= y.delta
            end
            ifNotKeepδThenFreeδ!(y)
        end
        addchild(y, x)
    end
    return y
end


function (v::Variable)(i...)
    if v.delta ≠ nothing
        return v.delta[i...]
    else
        return nothing
    end
end



# pretty printing
function Base.show(io::IO, ::MIME"text/plain", xv::XVariable)
    c, x = xv
    if  x.isleaf println(cyan!("\n═══ Leaf Variable ($c) ═══")) end
    if !x.isleaf println(cyan!("\n═══ None Leaf Variable ═══")) end

    print(yellow!("\nvalue is "))
    display(x.value)
    print(green!("\ndelta is "))
    display(x.delta)
end


elsizeof(x::Variable) = sizeof(eltype(x))


# lazy showing way of Variable's main vars
@inline ᵛ(x::Variable) = x.value
@inline ᵟ(x::Variable) = x.delta
@inline δ(x::Variable) = x.delta
@inline value(x::Variable) = x.value
@inline delta(x::Variable) = x.delta

# Variable's states fns
@inline isleaf(x::Variable)    = x.isleaf
@inline backprop(x::Variable)  = x.backprop
@inline keepsgrad(x::Variable) = x.keepsgrad
@inline needsgrad(x::Variable) = x.keepsgrad = true

@inline haskid(x::Variable)  = length(x.children) > 0 ? true : false
@inline kidsof(x::Variable)  =        x.children
@inline nkidsof(x::Variable) = length(x.children)


@inline ismarked(x::Variable)    = x.ismarked
@inline setmarked(x::Variable)   = x.ismarked = true
@inline unsetmarked(x::Variable) = x.ismarked = false

@inline isroot(x::Variable) = x.indegree == 0
@inline notempty(x::Variables) = length(x) ≠ 0

@inline addindegree(x::Variable)    = x.indegree += 1
@inline reduceindegree(x::Variable) = x.indegree -= 1

@inline function addchild(parent::Variable, kid::Variable)
    if !isleaf(kid)
        push!(parent.children, kid)
        addindegree(kid)
    end
end

@inline function addkid(parent::Variable, kid::Variable)
    if !isleaf(kid)
        push!(parent.children, kid)
        addindegree(kid)
    end
end


@inline function push!mark!(container::Vector, kid::Variable)
    push!(container, kid)
    setmarked(kid)
end

function VecVariable(n::Int=0)
    return Vector{Variable}(undef, n)
end

function VecXVariable(n::Int=0)
    return Vector{XVariable}(undef, n)
end


function setleaf(x::Variable)
    x.isleaf = true
    return nothing
end


# having the below defines, the activation function
# could be set nothing for blocks like Dense Conv
(f::Nothing)(x::AbstractArray) = x
(f::Nothing)(x::VarOrNil) = x
(f::Nothing)() = nothing

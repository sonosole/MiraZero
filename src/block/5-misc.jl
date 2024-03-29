kbytesof(b::B) where B <: Block = bytesof(b, "KB")
mbytesof(b::B) where B <: Block = bytesof(b, "MB")
gbytesof(b::B) where B <: Block = bytesof(b, "GB")
tbytesof(b::B) where B <: Block = bytesof(b, "TB")


function bytesof(blocks::Vector, unit::String="kb")
    n = 0
    for b in blocks
        if b isa Block
            n += bytesof(b, unit)
        end
    end
    return n
end


function kbytesof(blocks::Vector)
    n = 0
    for b in blocks
        if b isa Block
            n += kbytesof(b)
        end
    end
    return n
end


function mbytesof(blocks::Vector)
    n = 0
    for b in blocks
        if b isa Block
            n += mbytesof(b)
        end
    end
    return n
end


function gbytesof(blocks::Vector)
    n = 0
    for b in blocks
        if b isa Block
            n += gbytesof(b)
        end
    end
    return n
end


function tbytesof(blocks::Vector)
    n = 0
    for b in blocks
        if b isa Block
            n += tbytesof(b)
        end
    end
    return n
end


function paramsof(blocks::Vector)
    params = Vector{Variable}(undef,0)
    for b in blocks
        if b isa Block
            p = paramsof(b)
            if p ≠ nothing
                append!(params, p)
            end
        end
    end
    return params
end


function xparamsof(blocks::Vector)
    xparams = Vector{XVariable}(undef,0)
    for b in blocks
        if b isa Block
            p = xparamsof(b)
            if p ≠ nothing
                append!(xparams, p)
            end
        end
    end
    return xparams
end


function nparamsof(blocks::Vector)
    n = 0
    for b in blocks
        if b isa Block
            n += nparamsof(b)
        end
    end
    return n
end



paramsof(f::Function) = nothing
xparamsof(f::Function) = nothing
nparamsof(f::Function) = 0
nops(::Function, c::Int=1) = (0, 0, 0)
bytesof(::Function, unit::String="MB") = 0
elsizeof(::Function) = nothing


paramsof(::Nil)  = nothing
xparamsof(::Nil) = nothing
nparamsof(::Nil) = 0
nops(::Nil, c::Int=1) = (0, 0, 0)
bytesof(::Nil, unit::String="MB") = 0
elsizeof(::Nil) = nothing


"""
    checkvalues(x::AbstractArray)
If any value in x is NaN or Inf, throw a info
"""
function checkvalues(x::AbstractArray)
    for v in Array(x)
        if isnan(v) || isinf(v)
            @info red!("$v is unnormal")
            return nothing
        end
    end
end


function checkvalues(cv::Vector{XVariable})
    for (c, v) in cv
        checkvalues(value(v))
    end
end


function checkvalues(vs::Vector{Variable})
    for v in vs
        checkvalues(value(v))
    end
end


"""
    staticsof(x::AbstractArray) -> mean, std, min, max
"""
function staticsof(x::AbstractArray)
    μ = mean(x)
    σ = std(x, mean=μ)
    return μ, σ, minimum(x), maximum(x)
end


"""
    staticsof(cv::Vector{XVariable})
Show mean, std, min, max
"""
function staticsof(cv::Vector{XVariable})
    for (i, (c, v)) in enumerate(cv)
        μ, σ, l, u = staticsof(value(v))
        println("$(i)\t$(size(v))\t$c\t[$l, $u]\t($μ ± $σ)")
    end
end


"""
    staticsof(vs::Vector{Variable})
Show mean, std, min, max
"""
function staticsof(vs::Vector{Variable})
    for (i, v) in enumerate(vs)
        μ, σ, l, u = staticsof(value(v))
        println("$(i)\t$(size(v))\t[$l, $u]\t($μ\t±\t$σ)")
    end
end


function clone(f::Function; type::Type=Array{Float32})
    return f
end


function clone(f::ComposedFunction; type::Type=Array{Float32})
    return ComposedFunction(clone(f.inner; type), clone(f.outer; type))
end

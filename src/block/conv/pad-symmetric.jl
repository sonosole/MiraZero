export padsymmetric

"""
    padsymmetric(x::AbstractArray, pads::Pads{D}) where D

# Example
    julia> x = reshape(collect(1:6),1,6)
    1×6 Matrix{Int64}:
     1  2  3  4  5  6

    julia> padsymmetric(x,  ((0,0),(2,3)) )
    1×11 Matrix{Int64}:
     2  1 | 1  2  3  4  5  6 | 6  5  4
          ↑                  ↑
            symmetric points
"""
function padsymmetric(x::AbstractArray, pads::Pads{D}) where D
    paddings(pads) == 0 && return x
    ysize, xranges = ysize_and_xrange_when_pad(x, pads)
    y = fill!(similar(x, ysize), 0)
    y[xranges] = x

    N = ndims(y)
    for d = 1:D
        padleft  = pads[d][1]≠0
        padright = pads[d][2]≠0
        if padleft
            P = min(pads[d][1], size(x,d))   # left paddings
            E = first(xranges.indices[d])    # left side edge index
            dstᵢ = ntuple(k -> k≠d ? (1:ysize[k]) : (E-1:-1:E-P), N)
            srcᵢ = ntuple(k -> k≠d ? (1:ysize[k]) : (E  : E+P-1), N)
            y[CartesianIndices(dstᵢ)] .= y[CartesianIndices(srcᵢ)]
        end
        if padright
            P = min(pads[d][2], size(x,d))   # right paddings
            E = last(xranges.indices[d])     # right side edge index
            dstᵢ = ntuple(k -> k≠d ? (1:ysize[k]) : (E+1  : E+P), N)
            srcᵢ = ntuple(k -> k≠d ? (1:ysize[k]) : (E :-1:E-P+1), N)
            y[CartesianIndices(dstᵢ)] .= y[CartesianIndices(srcᵢ)]
        end
    end
    return y
end


function padsymmetric(x::Variable{T}, pads::Pads{D}) where {T,D}
    paddings(pads) == 0 && return x
    ysize, xranges = ysize_and_xrange_when_pad(ᵛ(x), pads)
    v = fill!(similar(ᵛ(x), ysize), 0)
    y = Variable{T}(v, x.backprop)
    v[xranges] = ᵛ(x)

    N = ndims(y)
    for d = 1:D
        padleft  = pads[d][1]≠0
        padright = pads[d][2]≠0
        if padleft
            P = min(pads[d][1], size(x,d))   # left paddings
            E = first(xranges.indices[d])    # left side edge index
            dstᵢ = ntuple(k -> k≠d ? (1:ysize[k]) : (E-1:-1:E-P), N)
            srcᵢ = ntuple(k -> k≠d ? (1:ysize[k]) : (E  : E+P-1), N)
            ᵛ(y)[CartesianIndices(dstᵢ)] .= ᵛ(y)[CartesianIndices(srcᵢ)]
        end
        if padright
            P = min(pads[d][2], size(x,d))   # right paddings
            E = last(xranges.indices[d])     # right side edge index
            dstᵢ = ntuple(k -> k≠d ? (1:ysize[k]) : (E+1  : E+P), N)
            srcᵢ = ntuple(k -> k≠d ? (1:ysize[k]) : (E :-1:E-P+1), N)
            ᵛ(y)[CartesianIndices(dstᵢ)] .= ᵛ(y)[CartesianIndices(srcᵢ)]
        end
    end

    if y.backprop
        y.backward = function ∇padsymmetric()
            if needgrad(x)
                zerodelta(x)
                for d = 1:D
                    padleft  = pads[d][1]≠0
                    padright = pads[d][2]≠0
                    if padleft
                        P = min(pads[d][1], size(x,d))   # left paddings
                        E = first(xranges.indices[d])    # left side edge index
                        dstᵢ = ntuple(k -> k≠d ? (1:ysize[k]) : (E-1:-1:E-P), N)
                        srcᵢ = ntuple(k -> k≠d ? (1:ysize[k]) : (E  : E+P-1), N)
                        ᵟ(y)[CartesianIndices(srcᵢ)] += ᵟ(y)[CartesianIndices(dstᵢ)]
                    end
                    if padright
                        P = min(pads[d][2], size(x,d))   # right paddings
                        E = last(xranges.indices[d])     # right side edge index
                        dstᵢ = ntuple(k -> k≠d ? (1:ysize[k]) : (E+1  : E+P), N)
                        srcᵢ = ntuple(k -> k≠d ? (1:ysize[k]) : (E :-1:E-P+1), N)
                        ᵟ(y)[CartesianIndices(srcᵢ)] += ᵟ(y)[CartesianIndices(dstᵢ)]
                    end
                end
                x ← ᵟ(y)[xranges]
            end
        end
        addchild(y, x)
    end
    return y
end

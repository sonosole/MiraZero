export TCS, seqtcs
export TCSGreedySearch
export TCSGreedySearchWithTimestamp

"""
    seqtcs(seq::Vector{Int}, background::Int=1, foreground::Int=2) -> newseq
expand `seq` with `background` and `foreground`'s indexes. For example, if `seq` is [i,j,k], then
`newseq` is [`B`, F,i, `B`, F,j, `B`, F,k, `B`], of which B is `background` index and F is `foreground` index.

# Example
    julia> seqtcs([7,3,5], 2, 4)'
    1×10 LinearAlgebra.Adjoint{Int64,Array{Int64,1}}:
     2  4  7  2  4  3  2  4  5  2
"""
function seqtcs(seq::VecInt, background::Int=1, foreground::Int=2)
    if seq[1] == 0
        return [background]
    end
    L = length(seq)       # sequence length
    N = 3 * L + 1         # topology length
    label = zeros(Int, N)
    label[1:3:N] .= background
    label[2:3:N] .= foreground
    label[3:3:N] .= seq
    return label
end

"""
    TCS(p::Array{T,2}, seqlabel::Vector{Int}; background::Int=1, foreground::Int=2) -> target, lossvalue
# Inputs
+ `p`        : probability of softmax output
+ `seqlabel` : like [i,j,k], i/j/k is neither background state nor foreground state. If `p` has no label (e.g. pure noise) then `seq` is [0].
# Outputs
+ `target`    : target of softmax's output
+ `lossvalue` : negative log-likelyhood
"""
function TCS(p::Array{TYPE,2}, seqlabel::VecInt; background::Int=1, foreground::Int=2) where TYPE
    seq  = seqtcs(seqlabel, background, foreground)
    ZERO = TYPE(0)                             # typed zero,e.g. Float32(0)
    S, T = size(p)                             # assert p is a 2-D tensor
    L = length(seq)                            # topology length
    r = fill!(Array{TYPE,2}(undef,S,T), ZERO)  # 𝜸 = p(s[k,t] | x[1:T]), k in softmax's indexing

    if L == 1
        r[background,:] .= TYPE(1)
        return r, - sum(log.(p[background,:]))
    end

    Log0 = LogZero(TYPE)                       # approximate -Inf of TYPE
    a = fill!(Array{TYPE,2}(undef,L,T), Log0)  # 𝜶 = p(s[k,t], x[1:t]), k in TCS topology's indexing
    b = fill!(Array{TYPE,2}(undef,L,T), Log0)  # 𝛃 = p(x[t+1:T] | s[k,t]), k in TCS topology's indexing
    a[1,1] = log(p[seq[1],1])  # background entrance
    a[2,1] = log(p[seq[2],1])  # foreground entrance
    b[L-1,T] = ZERO
    b[L-0,T] = ZERO

    # --- forward in log scale ---
	for t = 2:T
        τ = t-1
	    for s = 1:L
	        if s≠1
				R = mod(s,3)
	            if R==1 || s==2 || R==0
	                a[s,t] = LogSum2Exp(a[s,τ], a[s-1,τ])
	            elseif R==2
	                a[s,t] = LogSum3Exp(a[s,τ], a[s-1,τ], a[s-2,τ])
	            end
	        else
	            a[s,t] = a[s,τ]
	        end
	        a[s,t] += log(p[seq[s],t])
	    end
	end

    # --- backward in log scale ---
	for t = T-1:-1:1
        τ = t+1
		for s = L:-1:1
			Q⁰ = b[s,τ] + log(p[seq[s],τ])
			if s≠L
				R = mod(s,3)
				Q¹ = b[s+1,τ] + log(p[seq[s+1],τ])
				if R==1 || R==2 || s==L-1
					b[s,t] = LogSum2Exp(Q⁰, Q¹)
				elseif R==0
                    Q² = b[s+2,τ] + log(p[seq[s+2],τ])
					b[s,t] = LogSum3Exp(Q⁰, Q¹, Q²)
				end
			else
				b[s,t] = Q⁰
			end
		end
	end

    # loglikely of TCS
    logsum = LogSum2Exp(a[1,1] + b[1,1], a[2,1] + b[2,1])

    # log weight --> normal probs
	g = exp.((a + b) .- logsum)

    # Reduce First line
    r[seq[1],:] .+= g[1,:]
    # Reduce other lines
    for n = 1:div(L-1,3)
        s = 3*n
        r[seq[s-1],:] .+= g[s-1,:]  # reduce forground states
        r[seq[s  ],:] .+= g[s,  :]  # reduce labels' states
        r[seq[s+1],:] .+= g[s+1,:]  # reduce background state
    end

    return r, -logsum
end


"""
    TCSGreedySearch(x::Array; background::Int=1, foreground::Int=2, dims=1) -> hypothesis
remove repeats and background/foreground of argmax(x, dims=dims)
"""
function TCSGreedySearch(x::Array; background::Int=1, foreground::Int=2, dims=1)
    hyp = Vector{Int}(undef, 0)
    idx = argmax(x,dims=dims)
    for t = 1:length(idx)
        previous = idx[t≠1 ? t-1 : t][1]
        current  = idx[t][1]
        if !((current==previous && t≠1) ||
             (current==background) ||
             (current==foreground))
            push!(hyp, current)
        end
    end
    return hyp
end

"""
    TCSGreedySearch(x::Array; background::Int=1, foreground::Int=2, dims=1) -> hypothesis, timestamp
"""
function TCSGreedySearchWithTimestamp(x::Array; background::Int=1, foreground::Int=2, dims=1)
    hyp = Vector{Int}(undef, 0)
    stp = Vector{Float32}(undef, 0)
    idx = argmax(x,dims=dims)
    T   = length(idx)
    for t = 1:T
        previous = idx[t≠1 ? t-1 : t][1]
        current  = idx[t][1]
        if !((current==previous && t≠1) ||
             (current==background) ||
             (current==foreground))
            push!(hyp, current)
            push!(stp, t / T)
        end
    end
    return hyp, stp
end

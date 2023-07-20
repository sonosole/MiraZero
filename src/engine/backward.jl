export backward
export backprop

function backward(y::Variable{T},
                  δy::Union{Real,T}=1.0f0;
                  partial::Bool=false,
                  keepgraph::Bool=false,
                  by::String="dfs") where T


    filldelta(y, δy)

    # partial==true means y is one of the loss functions
    partial && resetindegree(y)

    if by=="dfs"
        sorted = sort_by_dfs(y)
    end
    if by=="bfs"
        sorted = sort_by_bfs(y)
    end

    if !keepgraph
        for v in sorted
            v.backward()
            free(v)
        end
    else
        for v in sorted
            v.backward()
        end
    end
end



function backprop(sorted::Vector{Variable})
    for node in sorted
        node.backward()
    end
end

function free(x::Variable{<:AbstractArray})
    x.value    = nothing
    x.backward = nothing
    x.children = nothing
    x          = nothing
end

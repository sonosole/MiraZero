export sort_by_recursive_dfs
export sort_by_bfs
export sort_by_dfs

"""
    sort_by_recursive_dfs(rootnode::Variable) -> stack
"""
function sort_by_recursive_dfs(entry::Variable)
    stack = Vector{Variable}()

    function visit(node::Variable)
        setmarked(node)
        if haskid(node)
            for kid in kidsof(node)
                if !ismarked(kid)
                    visit(kid)
                end
            end
        end
        push!(stack, node)
    end

    visit(entry)
    return stack
end



"""
    sort_by_bfs(rootnode::Variable) -> queue::Vector{Variable}
"""
function sort_by_bfs(entry::Variable)
    @assert isroot(entry) "not a root node"
    sorted = Vector{Variable}()
    queue  = Vector{Variable}()

    push!(queue, entry)
    while notempty(queue)
        node = popfirst!(queue)
        push!(sorted, node)
        if haskid(node)
            for kid in kidsof(node)
                kid.indegree -= 1
                if kid.indegree == 0
                    push!(queue, kid)
                end
            end
        end
    end

    return sorted
end


"""
    sort_by_bfs(rootnode::Variable) -> stack::Vector{Variable}
"""
function sort_by_dfs(entry::Variable)
    @assert isroot(entry) "not a root node"
    sorted = Vector{Variable}()
    stack  = Vector{Variable}()

    push!(stack, entry)
    while notempty(stack)
        node = pop!(stack)
        push!(sorted, node)
        if haskid(node)
            for kid in kidsof(node)
                kid.indegree -= 1
                if kid.indegree == 0
                    push!(stack, kid)
                end
            end
        end
    end

    return sorted
end

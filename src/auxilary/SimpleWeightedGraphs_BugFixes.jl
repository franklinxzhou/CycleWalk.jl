# Brute-force (`_bf`) graph predicates that work around a SimpleWeightedGraphs.jl
# quirk: an explicitly-stored zero weight is still reported as an edge by the
# library's `edges`/`neighbors`, so the stock `ne`/`is_connected` overcount edges
# and connectivity. These versions ignore zero-weight entries.

"""
    ne_bf(g)::Int

Count the edges of a `SimpleWeightedGraph`, excluding stored zero-weight entries
that `SimpleWeightedGraphs` would otherwise report as edges.
"""
function ne_bf(g::SimpleWeightedGraph)::Int
    return length(filter(e -> has_edge(g, e.src, e.dst), collect(edges(g))))
end

"""
    connected_components_bf!(label, g)

Label the connected components of `g` into the preallocated vector `label` via BFS,
treating zero-weight entries as non-edges. `label[v]` is set to a representative
vertex of `v`'s component. Returns `label`.
"""
function connected_components_bf!(
    label::AbstractVector,
    g::SimpleWeightedGraph{T}
) where T
    nvg = nv(g)

    for u in vertices(g)
        label[u] != zero(T) && continue
        label[u] = u
        Q = Vector{T}()
        push!(Q, u)
        while !isempty(Q)
            src = popfirst!(Q)
            for vertex in all_neighbors(g, src)
                if g.weights[src, vertex] == 0
                    continue
                end
                if label[vertex] == zero(T)
                    push!(Q, vertex)
                    label[vertex] = u
                end
            end
        end
    end
    return label
end

"""
    connected_components_bf(g)

Return the connected components of `g` (each as a vector of vertices), ignoring
zero-weight entries. Allocates the label vector and calls
[`connected_components_bf!`](@ref).
"""
function connected_components_bf(g::SimpleWeightedGraph{T}) where T
    label = zeros(T, nv(g))
    connected_components_bf!(label, g)
    c, d = Graphs.components(label)
    return c
end

"""
    is_connected_bf(g)

Return `true` if `g` is connected, ignoring zero-weight entries. Cheaply rejects
graphs with too few edges before computing components.
"""
function is_connected_bf(g::SimpleWeightedGraph)
    return ne_bf(g) + 1 >= nv(g) && length(connected_components_bf(g)) == 1
end
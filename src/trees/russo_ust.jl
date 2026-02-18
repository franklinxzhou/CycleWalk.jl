"""
    russo_ust(g, distmx=weights(g))

Return a vector of edges representing a uniform spanning tree (potentially weighted)
of an undirected graph `g` with optional distance matrix (or weights) `distmx` using [Russo's algorithm](https://www.mdpi.com/1999-4893/11/4/53).

### Optional Arguments
- `steps=nothing`: gives the heuristic presented in the reference above otherwise specify with an int
- `distmx=weights(g)`: matrix of weights of g
- `startingTree=dfs_tree(g)`: any tree (can be directed), which will be modified as in Russo's algorithm.
- `rng=MersenneTwister()`: An AbstractRNG object used for all random choices.
"""

function kruskal_rmst(
    g::SimpleWeightedGraph,
    rng::AbstractRNG;
    minimize=false
)
    connected_vs = IntDisjointSets(nv(g))

    mst = Vector{edgetype(g)}()
    sizehint!(mst, nv(g) - 1)

    weights = Vector{Float64}()
    sizehint!(weights, ne(g))

    edge_list = collect(edges(g))
    for e in edges(g)
        push!(weights, rand(rng)*g.weights[src(e), dst(e)])
    end

    for e in edge_list[sortperm(weights; rev=!minimize)]
        if !in_same_set(connected_vs, src(e), dst(e))
            union!(connected_vs, src(e), dst(e))
            push!(mst, e)
            (length(mst) >= nv(g) - 1) && break
        end
    end

    return mst
end

# see https://github.com/mauro3/SimpleTraits.jl/issues/47#issuecomment-327880153 for syntax
function russo_ust(
    g::SimpleWeightedGraph, rng::AbstractRNG=MersenneTwister(); 
    # distmx::AbstractMatrix{T}=SimpleWeightedGraphs.weights(g); 
    steps::Union{Nothing, Int}=nothing, 
    startingTree=kruskal_rmst(g, rng)
)
    if steps === nothing
        # steps = (round(nv(g)^1.3 + ne(g)))
        steps = ne(g)*log(ne(g))/4
    end

    # ust = link_cut_tree(startingTree)
    ust = link_cut_tree(g, startingTree)

    #choosing randomly from a set is more efficient
    g_edges = Set(edges(g))

    #in each step:
    for i in 1:steps
        #choose an edge e=(u,v) in g uniformly at random
        e = rand(rng,g_edges)
        u = ust.nodes[src(e)]
        v = ust.nodes[dst(e)]
        # get a path from u to v
        evert!(u)
        expose!(v)
        D = findPath(v)
        # if e is in ust already, move on.
        if length(D) == 2
            continue
        end
        # from v, find parents [v to parent, + parent to next parent, cum + next weight, ..., sum of the weights]
        pathWeights = Float64[0]
        cumWeight = 0
        for n in 2:lastindex(D)
            w = g.weights[D[n-1].vertex,D[n].vertex]
            cumWeight += (1/w)
            append!(pathWeights,[cumWeight])
        end

        cumWeight += 1/g.weights[u.vertex, v.vertex]
        # randSamp = rand()*sum of the weights
        randSamp = rand(rng)*cumWeight
        if randSamp > pathWeights[end]
            continue
        end
        for i in 1:lastindex(pathWeights)
            if (randSamp > pathWeights[i]) && (randSamp <= pathWeights[i+1])
                cut!(D[i+1])
                evert!(v)
                link!(v,u)
                break
            end
        end
    end

    #convert the link-cut tree back into a vector of edges for output
    edgeVector = edgetype(g)[]
    sizehint!(edgeVector, nv(g)-1)

    prnts = parents(ust)
    for edge in edges(g)
        if prnts[dst(edge)] == src(edge) || prnts[src(edge)] == dst(edge)
            push!(edgeVector,edge)
        end
    end
    return edgeVector
end
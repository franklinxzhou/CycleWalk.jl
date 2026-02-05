function get_rand_internal_edge(
    partition::LinkCutPartition,
    rng::AbstractRNG
)
    while true
        edges = partition.graph.edge_attributes
        e = rand_dict_key(rng, edges)
        u, v = collect(e)
        ru = find_root!(partition.lct.nodes[u])
        rv = find_root!(partition.lct.nodes[v])
        ru == rv && return (u,v)
    end
end

function repair_partition!(
    partition::LinkCutPartition,
    linked_node::Node,
    original_root::Node
)
    new_root = find_root!(linked_node)
    district = partition.roots_to_district[original_root.vertex]
    delete!(partition.roots_to_district, original_root.vertex)
    partition.roots_to_district[new_root.vertex] = district
    partition.district_roots[district] = new_root.vertex 
end

function getCummulativePathWeight(
    partition::LinkCutPartition, 
    path::Vector{Node},
    link::Tuple{Node, Node}
)
    pathWeights = Float64[0]
    g = partition.graph.simple_graph
    cumWeight = 0
    for n in 2:lastindex(path)
        w = g.weights[path[n-1].vertex,path[n].vertex]
        cumWeight += (1/w)
        append!(pathWeights,[cumWeight])
    end
    cumWeight += 1/g.weights[link[1].vertex, link[2].vertex]
    return pathWeights, cumWeight
end

function internal_forest_walk!(
    partition::LinkCutPartition,
    rng::AbstractRNG;
    diagnostics::Union{Nothing,ProposalDiagnostics}=nothing,
    edge::Union{Tuple{Int64, Int64}, Nothing}=nothing
)
    if edge === nothing
        edge = get_rand_internal_edge(partition, rng)
    end

    u = partition.lct.nodes[edge[1]]
    v = partition.lct.nodes[edge[2]]
    r = find_root!(u)

    evert!(u)
    expose!(v)
    path = findPath(v)
    if length(path) == 2
        repair_partition!(partition, v, r)
        return 0, nothing
    end

    pathWeights, cumWeight = getCummulativePathWeight(partition, path, (u,v))

    # edge_ind = rand(rng, 1:length(D))
    randSamp = rand(rng)*cumWeight
    if randSamp > pathWeights[end]
        repair_partition!(partition, v, r)
        return 0, nothing
    end

    for edge_ind in 1:lastindex(pathWeights)
        if ((randSamp > pathWeights[edge_ind]) && 
            (randSamp <= pathWeights[edge_ind+1]))
            cut!(path[edge_ind+1])
            new_root = find_root!(v)
            link!(u,v)
            district = partition.roots_to_district[r.vertex]
            delete!(partition.roots_to_district, r.vertex)
            partition.roots_to_district[new_root.vertex] = district
            partition.district_roots[district] = new_root.vertex
            return 0, nothing
        end
    end
    println("Error: escaped edge detection")
    @assert false
end

""""""
function build_internal_forest_walk(
    constraints::Dict{Type{T} where T<:AbstractConstraint, AbstractConstraint}
)
    f(p, r; diagnostics=nothing) = internal_forest_walk!(p, r;
                                                        diagnostics=diagnostics)
    return f
end

const build_one_tree_cycle_walk = build_internal_forest_walk
const one_tree_cycle_walk! = internal_forest_walk!

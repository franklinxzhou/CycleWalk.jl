""""""
function flatten_assignment(
    partition::MultiLevelPartition
)::Dict{Tuple{Vararg{String}}, Int}
    levels = partition.graph.levels
    base_graph = partition.graph.graphs_by_level[end]
    node_to_district = Dict{Tuple{Vararg{String}}, Int}()

    for ni = 1:base_graph.num_nodes
        node_attrs = base_graph.node_attributes[ni]
        node = Tuple(string(node_attrs[level]) for level in levels)
        district = mfr_get_district(partition, node)
        @assert district !== nothing
        
        node_to_district[(node[end],)] = district
    end

    return node_to_district
end

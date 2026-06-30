"""
    get_log_district_trees(partition, districts=...; update=nothing)::Float64

Build the district adjacency graph — one vertex per district, each adjacent pair
joined by an edge weighted by the total weight of edges crossing between them — and
return the log number of (weighted) spanning trees of that graph. When an `update` is
supplied, pairs touching the changed districts use the update's recomputed boundary
weights. Measures how richly connected the district-level graph is.
"""
function get_log_district_trees(
    partition::LinkCutPartition,
    districts::Union{Tuple{Vararg{T}}, Vector{T}}
        =collect(1:partition.num_dists);
    update::Union{Update{T}, Nothing}=nothing
)::Float64 where T <: Int
    changed_dists = ()
    new_cross_d_edg = typeof(partition.cross_district_edges)()
    if update !== nothing
        changed_dists = update.changed_districts
        new_cross_d_edg = update.new_cross_d_edg
    end

    g = SimpleWeightedGraph(partition.num_dists)

    for key in keys(partition.cross_district_edges)
        if length(intersect(key, changed_dists)) > 0
            continue
        end
        pair_sum = 0
        for e in partition.cross_district_edges[key]
            pair_sum += weight(e)
        end
        add_edge!(g, key[1], key[2], pair_sum)
    end

    for key in keys(new_cross_d_edg)
        pair_sum = 0
        for e in new_cross_d_edg[key]
            pair_sum += weight(e)
        end
        add_edge!(g, key[1], key[2], pair_sum)
    end
    return log_nspanning(g)
end
# in above, could past a dictionary and set of keys
# update would be new_cross_d_edg and keys(new_cross_d_edg)
#!update would be partition.cross_district_edges and key subset or whole

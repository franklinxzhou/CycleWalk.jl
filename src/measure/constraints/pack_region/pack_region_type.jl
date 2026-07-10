"""
    PackRegionConstraint <: AbstractConstraint

Constraint requiring each region (a value of the `region` node attribute) to be
"packed" with whole districts: at least its proportional share of districts must lie
entirely inside it. `region_to_packed_dists` records the required count per region,
`region_to_nodes` the region membership, and `ideal_pop` the per-district ideal
population the share was computed from. Construct with the method below.
"""
struct PackRegionConstraint <: AbstractConstraint
    region_to_nodes::Dict{String, Vector{Int}}
    region_to_packed_dists::Dict{String,Int}
    region::String
    desc::String
    ideal_pop::T where T <: Real
end

"""
    PackRegionConstraint(graph, region; unpack=0, num_dists=0, ideal_pop=0)

Build a [`PackRegionConstraint`](@ref) on the `region` attribute of `graph`. The
required packed-district count for each region is `floor(region_pop / ideal_pop) -
unpack` (only regions with a positive requirement are kept). Provide either
`ideal_pop` directly or `num_dists` to derive it from the total population; `unpack`
relaxes the requirement by that many districts.
"""
function PackRegionConstraint(
    graph::Graph,
    region::String;
    unpack::Int=0,
    num_dists::Int=0,
    ideal_pop::Real=0
)::PackRegionConstraint
    if ideal_pop == 0 && num_dists == 0
        throw(
            ArgumentError("Need to specify either ideal_pop or num_dists",)
        )
    elseif ideal_pop == 0
        ideal_pop = graph.graphs_by_level[end].total_pop / num_dists
    end
    base_graph = graph.graphs_by_level[end]

    regions_pop = Dict{String, T where T<:Real}()
    region_nodes = Dict{String, Vector{Int}}()
    region_to_packed_dists = Dict{String, Int}()
    regions = Set([base_graph.node_attributes[ii][region]
                   for ii = 1:base_graph.num_nodes])
    pop_col = base_graph.pop_col

    for node_id = 1:base_graph.num_nodes
        region_name = base_graph.node_attributes[node_id][region]

        node_pop = base_graph.node_attributes[node_id][pop_col]
        regions_pop[region_name] = get(regions_pop, region_name, 0) + node_pop

        region_nodes[region_name] = get(region_nodes, region_name, Int[])
        push!(region_nodes[region_name], node_id)
    end

    for (region_name, pop) in regions_pop
        packed_districts = Int(floor(pop / ideal_pop)) - unpack
        if packed_districts > 0
            region_to_packed_dists[region_name] = packed_districts
        else
            delete!(region_nodes, region_name)
        end
    end
    return PackRegionConstraint(region_nodes, region_to_packed_dists, region, 
                                region*"_unpack"*string(unpack), ideal_pop)
end
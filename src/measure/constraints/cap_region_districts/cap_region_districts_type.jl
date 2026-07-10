"""
    CapRegionDistricts <: AbstractConstraint

Constraint capping how many districts may touch each region (a value of the `region`
node attribute), to limit how finely regions are split. `region_to_dist_cap` records
the cap per region, `region_to_nodes` the region membership, and `ideal_pop` the
per-district ideal population the cap was computed from. Also available under the
alias `CapRegionDistConstraint`. Construct with the method below.
"""
struct CapRegionDistricts <: AbstractConstraint
    region_to_nodes::Dict{String, Vector{Int}}
    region_to_dist_cap::Dict{String, Int}
    region::String
    desc::String
    ideal_pop::T where T <: Real
end

"""Alias for [`CapRegionDistricts`](@ref)."""
const CapRegionDistConstraint = CapRegionDistricts

"""
    CapRegionDistricts(graph, region; excess_split=0, num_dists=0, ideal_pop=0)

Build a [`CapRegionDistricts`](@ref) on the `region` attribute of `graph`. Each
region's district cap is `ceil(region_pop / ideal_pop) + excess_split` — its minimal
proportional district count plus an allowed slack. Provide either `ideal_pop` directly
or `num_dists` to derive it from the total population.
"""
function CapRegionDistricts(
    graph::Graph,
    region::String;
    excess_split::Int=0,
    num_dists::Int=0,
    ideal_pop::Real=0
)::CapRegionDistricts
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
    region_to_dist_cap = Dict{String, Int}()
    pop_col = base_graph.pop_col

    for node_id = 1:base_graph.num_nodes
        region_name = base_graph.node_attributes[node_id][region]

        node_pop = base_graph.node_attributes[node_id][pop_col]
        regions_pop[region_name] = get(regions_pop, region_name, 0) + node_pop

        region_nodes[region_name] = get(region_nodes, region_name, Int[])
        push!(region_nodes[region_name], node_id)
    end

    for (region_name, pop) in regions_pop
        min_touching_districts = Int(ceil(pop / ideal_pop))
        region_to_dist_cap[region_name] = min_touching_districts + excess_split
    end

    return CapRegionDistricts(region_nodes, region_to_dist_cap, region,
                              region * "_excess_split" * string(excess_split),
                              ideal_pop)
end
struct PackRegionConstraint <: AbstractConstraint
    region_to_nodes::Dict{String, Vector{Int}}
    region_to_packed_dists::Dict{String,Int}
    region::String
    desc::String
    ideal_pop::T where T <: Real
end

""""""
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
                                region, ideal_pop)
end

function satisfies_constraint(
    partition::LinkCutPartition,
    pack_region_constraint::PackRegionConstraint,
    districts::Union{Tuple{Vararg{T}}, Vector{T}} 
        = collect(1:partition.num_dists);
    update::Union{Update, Nothing}=nothing
)::Bool where T<:Int
    region = (pack_region_constraint.region,)
    if !haskey(partition.energy_data, (RegionalSplitData, region))
        data = RegionalSplitData(partition, pack_region_constraint.region)
        partition.energy_data[(RegionalSplitData, region)] = data
    end
    data = partition.energy_data[(RegionalSplitData, region)]

    if partition.identifier != data.identifier
        data = RegionalSplitData(partition, pack_region_constraint.region)
        partition.energy_data[(RegionalSplitData, region)] = data
    end
    if update !== nothing && update.identifier != data.update_identifier
        update_regional_split_data!(data, partition, update)
    end

    active_districts = districts
    active_regions_to_dists = data.regions_to_dists
    active_dists_to_regions = data.dists_to_regions
    if update !== nothing
        active_districts = collect(update.changed_districts)
        active_regions_to_dists = data.regions_to_dists_update
        active_dists_to_regions = data.dists_to_regions_update
    end

    return satisfies_constraint(pack_region_constraint,
                                active_districts,
                                active_regions_to_dists,
                                active_dists_to_regions)
end

function satisfies_constraint(
    pack_region_constraint::PackRegionConstraint,
    districts::Union{Tuple{Vararg{T}}, Vector{T}},
    regions_to_dists::Dict{String, Set{Int64}},
    dists_to_regions::Dict{Int64, Set{String}}
)::Bool where T<:Int
    checked_regions = Set{String}()

    for district in districts
        district_regions = dists_to_regions[district]
        for region in district_regions
            if region in checked_regions
                continue
            end
            push!(checked_regions, region)

            if !haskey(pack_region_constraint.region_to_packed_dists, region)
                # no packing requirement for this region, so skip
                continue
            end

            req_pack = pack_region_constraint.region_to_packed_dists[region]
       
            exclusive_count = 0
            for di in regions_to_dists[region]
                di_regions = dists_to_regions[di]
                if length(di_regions) == 1 && region in di_regions
                    exclusive_count += 1
                end
            end

            if exclusive_count < req_pack
                return false
            end
        end
    end

    return true
end

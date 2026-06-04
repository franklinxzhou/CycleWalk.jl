mutable struct RegionalSplitData <: AbstractEnergyData
    identifier::Int64
    update_identifier::Vector{Int64}
    regions_to_dists::Dict{String, Set{Int64}}
    dists_to_regions::Dict{Int64, Set{String}}
    regions_to_dists_update::Dict{String, Set{Int64}}
    dists_to_regions_update::Dict{Int64, Set{String}}
    region::String
end

function RegionalSplitData(partition::LinkCutPartition, region::String)
    identifier = partition.identifier
    update_identifier = Vector{Int64}(undef, 0)
    
    regions_to_dists = Dict{String, Set{Int64}}()
    dists_to_regions = Dict{Int64, Set{String}}()
    regions_to_dists_update = Dict{String, Set{Int64}}()
    dists_to_regions_update = Dict{Int64, Set{String}}()
    for ni in 1:length(partition.node_to_dist)
        name = partition.graph.node_attributes[ni][region]
        dist = partition.node_to_dist[ni]
        push!(get!(regions_to_dists, name, Set{Int64}()), dist)
        push!(get!(dists_to_regions, dist, Set{String}()), name)
    end
    return RegionalSplitData(identifier, update_identifier, 
                             regions_to_dists, dists_to_regions, 
                             regions_to_dists_update, 
                             dists_to_regions_update, region)
end

function update_regional_split_data!(
    data::RegionalSplitData,
    partition::LinkCutPartition,
    update::Update
)
    data.update_identifier = copy(update.identifier)
    region_col = data.region

    affected_regions = Set{String}()
    for di in update.changed_districts
        for region in data.dists_to_regions[di]
            push!(affected_regions, region)
        end
    end

    # Shallow-copy both dicts: unaffected entries share their value Vectors
    # with the committed dicts (safe because we replace, never mutate them).
    data.dists_to_regions_update = copy(data.dists_to_regions)
    data.regions_to_dists_update = copy(data.regions_to_dists)

    # Drop the entries to rebuild
    for di in update.changed_districts
        delete!(data.dists_to_regions_update, di)
    end
    for region in affected_regions
        delete!(data.regions_to_dists_update, region)
    end

    # Rebuild from node_to_dist_update (already the full proposed state).
    # Must iterate all nodes to correctly handle unchanged districts that
    # also contain parts of affected regions.
    for ni in 1:partition.graph.num_nodes
        region = partition.graph.node_attributes[ni][region_col]
        if region ∉ affected_regions
            continue
        end
        di = partition.node_to_dist_update[ni]
        push!(get!(data.dists_to_regions_update, di, Set{String}()), region)
        push!(get!(data.regions_to_dists_update, region, Set{Int64}()), di)
    end
end

function update_energy_data!(
    data::RegionalSplitData,
    partition::LinkCutPartition,
    update::Update{T}
) where T<:Int
    if update.identifier != data.update_identifier
        update_regional_split_data!(data, partition, update)
    end

    data.identifier = partition.identifier
    data.regions_to_dists = copy(data.regions_to_dists_update)
    data.dists_to_regions = copy(data.dists_to_regions_update)
end
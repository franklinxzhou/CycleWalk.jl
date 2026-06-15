function satisfies_constraint(
    partition::LinkCutPartition,
    brc::BudgetedRegionConstraint,
    districts::Union{Tuple{Vararg{T}}, Vector{T}}
        = collect(1:partition.num_dists);
    update::Union{Update, Nothing}=nothing
)::Bool where T<:Int
    region = (brc.region,)

    if !haskey(partition.energy_data, (RegionalSplitData, region))
        data = RegionalSplitData(partition, brc.region)
        partition.energy_data[(RegionalSplitData, region)] = data
    end

    data = partition.energy_data[(RegionalSplitData, region)]

    if partition.identifier != data.identifier
        data = RegionalSplitData(partition, brc.region)
        partition.energy_data[(RegionalSplitData, region)] = data
    end

    if update !== nothing && update.identifier != data.update_identifier
        update_regional_split_data!(data, partition, update)
    end

    active_regions_to_dists = data.regions_to_dists
    active_dists_to_regions = data.dists_to_regions

    if update !== nothing
        active_regions_to_dists = data.regions_to_dists_update
        active_dists_to_regions = data.dists_to_regions_update
    end

    return satisfies_constraint(
        brc,
        districts,
        active_regions_to_dists,
        active_dists_to_regions,
    )
end

function satisfies_constraint(
    brc::BudgetedRegionConstraint,
    districts::Union{Tuple{Vararg{T}}, Vector{T}},
    regions_to_dists::Dict{String, Set{Int64}},
    dists_to_regions::Dict{Int64, Set{String}},
)::Bool where T<:Int
    pack_excess = 0
    cap_excess = 0

    regions_to_check = union(
        Set(keys(brc.region_to_packed_dists)),
        Set(keys(brc.region_to_dist_cap)),
    )

    for region in regions_to_check
        if haskey(brc.region_to_packed_dists, region)
            req_pack = brc.region_to_packed_dists[region]
            touched_dists = get(regions_to_dists, region, Set{Int64}())

            exclusive_count = 0
            for di in touched_dists
                di_regions = dists_to_regions[di]
                if length(di_regions) == 1 && region in di_regions
                    exclusive_count += 1
                end
            end

            pack_excess += max(0, req_pack - exclusive_count)

            if pack_excess > brc.pack_budget
                return false
            end
        end

        if haskey(brc.region_to_dist_cap, region)
            touched_count = length(get(regions_to_dists, region, Set{Int64}()))
            cap_excess += max(0, touched_count - brc.region_to_dist_cap[region])

            if cap_excess > brc.cap_budget
                return false
            end
        end

        if pack_excess + cap_excess > brc.total_budget
            return false
        end
    end

    return true
end
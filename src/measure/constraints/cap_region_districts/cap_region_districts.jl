"""
    satisfies_constraint(partition, cap_region_constraint, districts=...; update=nothing)::Bool

Check the [`CapRegionDistricts`](@ref) constraint against `partition` (or the plan
implied by `update`). Uses the cached [`RegionalSplitData`](@ref) region↔district
maps (rebuilt if stale, extended for a proposed `update`) and delegates to the
low-level method. With an `update`, only the changed districts' regions are checked.
"""
function satisfies_constraint(
    partition::LinkCutPartition,
    cap_region_constraint::CapRegionDistricts,
    districts::Union{Tuple{Vararg{T}}, Vector{T}}
        = collect(1:partition.num_dists);
    update::Union{Update, Nothing}=nothing
)::Bool where T<:Int
    region = (cap_region_constraint.region,)
    if !haskey(partition.energy_data, (RegionalSplitData, region))
        data = RegionalSplitData(partition, cap_region_constraint.region)
        partition.energy_data[(RegionalSplitData, region)] = data
    end
    data = partition.energy_data[(RegionalSplitData, region)]

    if partition.identifier != data.identifier
        data = RegionalSplitData(partition, cap_region_constraint.region)
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

    return satisfies_constraint(cap_region_constraint,
                                active_districts,
                                active_regions_to_dists,
                                active_dists_to_regions)
end

"""
    satisfies_constraint(cap_region_constraint, districts, regions_to_dists, dists_to_regions)::Bool

Low-level cap check from the region↔district maps. For every region touched by
`districts` that has a cap, the constraint holds iff the number of districts
intersecting that region does not exceed its district cap.
"""
function satisfies_constraint(
    cap_region_constraint::CapRegionDistricts,
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

            if !haskey(cap_region_constraint.region_to_dist_cap, region)
                continue
            end

            district_cap = cap_region_constraint.region_to_dist_cap[region]
            district_count = length(regions_to_dists[region])
            if district_count > district_cap
                return false
            end
        end
    end

    return true
end
struct BudgetedRegionConstraint <: AbstractConstraint
    region_to_nodes::Dict{String, Vector{Int}}
    region_to_packed_dists::Dict{String, Int}
    region_to_dist_cap::Dict{String, Int}
    region::String
    desc::String
    ideal_pop::T where T <: Real
    total_budget::Int
    pack_budget::Int
    cap_budget::Int
    budget_mode::Symbol
end

function BudgetedRegionConstraint(
    graph::Graph,
    region::String;
    num_dists::Int=0,
    ideal_pop::Real=0,
    total_budget::Int,
    pack_budget::Union{Nothing, Int}=nothing,
    cap_budget::Union{Nothing, Int}=nothing,
    budget_mode::Symbol=:cap_only,
    rng=nothing,
)::BudgetedRegionConstraint
    if ideal_pop == 0 && num_dists == 0
        throw(ArgumentError("Need to specify either ideal_pop or num_dists"))
    elseif ideal_pop == 0
        ideal_pop = graph.graphs_by_level[end].total_pop / num_dists
    end

    if total_budget < 0
        throw(ArgumentError("total_budget must be nonnegative"))
    end

    if budget_mode == :cap_only
        realized_pack_budget = 0
        realized_cap_budget = total_budget
    elseif budget_mode == :pack_only
        realized_pack_budget = total_budget
        realized_cap_budget = 0
    elseif budget_mode == :fixed
        pack_budget === nothing &&
            throw(ArgumentError("pack_budget is required for budget_mode=:fixed"))
        cap_budget === nothing &&
            throw(ArgumentError("cap_budget is required for budget_mode=:fixed"))
        pack_budget >= 0 ||
            throw(ArgumentError("pack_budget must be nonnegative"))
        cap_budget >= 0 ||
            throw(ArgumentError("cap_budget must be nonnegative"))
        pack_budget + cap_budget <= total_budget ||
            throw(ArgumentError("pack_budget + cap_budget must be <= total_budget"))

        realized_pack_budget = pack_budget
        realized_cap_budget = cap_budget
    elseif budget_mode == :random
        rng === nothing &&
            throw(ArgumentError("rng is required for budget_mode=:random"))

        realized_pack_budget = rand(rng, 0:total_budget)
        realized_cap_budget = total_budget - realized_pack_budget
    else
        throw(ArgumentError("Unrecognized BRC budget_mode=$budget_mode"))
    end

    pack_baseline = PackRegionConstraint(
        graph,
        region;
        unpack=0,
        num_dists=num_dists,
        ideal_pop=ideal_pop,
    )

    cap_baseline = CapRegionDistricts(
        graph,
        region;
        num_dists=num_dists,
        ideal_pop=ideal_pop,
        excess_split=0,
    )

    desc = region *
           "_total_budget" * string(total_budget) *
           "_pack_budget" * string(realized_pack_budget) *
           "_cap_budget" * string(realized_cap_budget)

    return BudgetedRegionConstraint(
        pack_baseline.region_to_nodes,
        pack_baseline.region_to_packed_dists,
        cap_baseline.region_to_dist_cap,
        region,
        desc,
        ideal_pop,
        total_budget,
        realized_pack_budget,
        realized_cap_budget,
        budget_mode,
    )
end
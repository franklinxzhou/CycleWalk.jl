"""
    BudgetedRegionConstraint <: AbstractConstraint

Combined pack-and-cap region constraint that, instead of enforcing each region's pack
and cap requirements strictly, allows a bounded total amount of violation. It carries
both the per-region packed-district requirements (`region_to_packed_dists`) and
district caps (`region_to_dist_cap`), together with three budgets: `pack_budget` on
total pack shortfall, `cap_budget` on total cap excess, and `total_budget` on their
sum. `budget_mode` records how the pack/cap split was chosen. Construct with the
method below.
"""
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

"""
    BudgetedRegionConstraint(graph, region; total_budget, num_dists=0, ideal_pop=0,
                             pack_budget=nothing, cap_budget=nothing,
                             budget_mode=:cap_only, rng=nothing)

Build a [`BudgetedRegionConstraint`](@ref) on the `region` attribute of `graph`,
reusing the baseline pack and cap requirements from [`PackRegionConstraint`](@ref) and
[`CapRegionDistricts`](@ref). `budget_mode` determines how `total_budget` is split
between pack and cap:
- `:cap_only` — all budget goes to cap excess (pack budget 0).
- `:pack_only` — all budget goes to pack shortfall (cap budget 0).
- `:fixed` — use the explicit `pack_budget` and `cap_budget` (must sum to ≤ `total_budget`).
- `:random` — split `total_budget` randomly (requires `rng`).

Provide either `ideal_pop` directly or `num_dists` to derive it.
"""
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
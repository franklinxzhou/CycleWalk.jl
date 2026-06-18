name = "BudgetedRegionConstraint statewide cap budget"

@testset "$name" begin
    regions_to_dists = Dict{String, Set{Int64}}(
        "A" => Set{Int64}([1, 2]),
        "B" => Set{Int64}([3, 4]),
    )

    dists_to_regions = Dict{Int64, Set{String}}(
        1 => Set{String}(["A"]),
        2 => Set{String}(["A"]),
        3 => Set{String}(["B"]),
        4 => Set{String}(["B"]),
    )

    all_districts = collect(1:4)

    strict_caps = Dict{String, Int}(
        "A" => 1,
        "B" => 1,
    )

    cap_excess_split_one = CapRegionDistricts(
        Dict{String, Vector{Int}}(
            "A" => Int[],
            "B" => Int[],
        ),
        Dict{String, Int}(
            "A" => 2,
            "B" => 2,
        ),
        "county",
        "county_excess_split1",
        1.0,
    )

    brc_cap_budget_one = BudgetedRegionConstraint(
        Dict{String, Vector{Int}}(
            "A" => Int[],
            "B" => Int[],
        ),
        Dict{String, Int}(),
        strict_caps,
        "county",
        "county_total_budget1_pack_budget0_cap_budget1",
        1.0,
        1,
        0,
        1,
        :cap_only,
    )

    brc_cap_budget_two = BudgetedRegionConstraint(
        Dict{String, Vector{Int}}(
            "A" => Int[],
            "B" => Int[],
        ),
        Dict{String, Int}(),
        strict_caps,
        "county",
        "county_total_budget2_pack_budget0_cap_budget2",
        1.0,
        2,
        0,
        2,
        :cap_only,
    )

    @testset "CapRegionDistricts excess_split is local per region" begin
        @test satisfies_constraint(
            cap_excess_split_one,
            all_districts,
            regions_to_dists,
            dists_to_regions,
        )
    end

    @testset "BudgetedRegionConstraint cap budget is statewide" begin
        @test !satisfies_constraint(
            brc_cap_budget_one,
            all_districts,
            regions_to_dists,
            dists_to_regions,
        )

        @test satisfies_constraint(
            brc_cap_budget_two,
            all_districts,
            regions_to_dists,
            dists_to_regions,
        )
    end

    @testset "BudgetedRegionConstraint does not check only changed districts" begin
        # if the BRC check only looked at district 1's region, it would see
        # only region A's one extra touch and incorrectly pass under budget 1.
        # Correct behavior recomputes the global excess: A contributes 1,
        # B contributes 1, total excess is 2, so budget 1 fails.
        @test !satisfies_constraint(
            brc_cap_budget_one,
            [1],
            regions_to_dists,
            dists_to_regions,
        )
    end
end
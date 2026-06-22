name = "BudgetedRegionConstraint statewide budget"

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

        @testset "BudgetedRegionConstraint pack_only budgets missing packed districts" begin
        # In the toy setup:
        #   region A has wholly-inside districts 1 and 2
        #   region B has wholly-inside districts 3 and 4
        #
        # Requiring A -> 3 and B -> 2 creates exactly one missing packed district.
        pack_requirements = Dict{String, Int}(
            "A" => 3,
            "B" => 2,
        )

        # Use loose caps here so this test isolates the pack side.
        loose_caps = Dict{String, Int}(
            "A" => 10,
            "B" => 10,
        )

        brc_pack_budget_zero = BudgetedRegionConstraint(
            Dict{String, Vector{Int}}(
                "A" => Int[],
                "B" => Int[],
            ),
            pack_requirements,
            loose_caps,
            "county",
            "county_total_budget0_pack_budget0_cap_budget0",
            1.0,
            0,
            0,
            0,
            :pack_only,
        )

        brc_pack_budget_one = BudgetedRegionConstraint(
            Dict{String, Vector{Int}}(
                "A" => Int[],
                "B" => Int[],
            ),
            pack_requirements,
            loose_caps,
            "county",
            "county_total_budget1_pack_budget1_cap_budget0",
            1.0,
            1,
            1,
            0,
            :pack_only,
        )

        @test !satisfies_constraint(
            brc_pack_budget_zero,
            all_districts,
            regions_to_dists,
            dists_to_regions,
        )

        @test satisfies_constraint(
            brc_pack_budget_one,
            all_districts,
            regions_to_dists,
            dists_to_regions,
        )
    end

    @testset "BudgetedRegionConstraint fixed mode enforces pack, cap, and total budgets" begin
        # This combines the two sources of excess in the same toy setup:
        #
        #   pack_excess = 1:
        #       A requires 3 whole districts but has only 2.
        #
        #   cap_excess = 2:
        #       A touches 2 districts with cap 1.
        #       B touches 2 districts with cap 1.
        #
        #   total_excess = 3.
        pack_requirements = Dict{String, Int}(
            "A" => 3,
            "B" => 2,
        )

        brc_fixed_pass = BudgetedRegionConstraint(
            Dict{String, Vector{Int}}(
                "A" => Int[],
                "B" => Int[],
            ),
            pack_requirements,
            strict_caps,
            "county",
            "county_total_budget3_pack_budget1_cap_budget2",
            1.0,
            3,
            1,
            2,
            :fixed,
        )

        brc_fixed_total_too_small = BudgetedRegionConstraint(
            Dict{String, Vector{Int}}(
                "A" => Int[],
                "B" => Int[],
            ),
            pack_requirements,
            strict_caps,
            "county",
            "county_total_budget2_pack_budget1_cap_budget2",
            1.0,
            2,
            1,
            2,
            :fixed,
        )

        brc_fixed_pack_too_small = BudgetedRegionConstraint(
            Dict{String, Vector{Int}}(
                "A" => Int[],
                "B" => Int[],
            ),
            pack_requirements,
            strict_caps,
            "county",
            "county_total_budget3_pack_budget0_cap_budget2",
            1.0,
            3,
            0,
            2,
            :fixed,
        )

        brc_fixed_cap_too_small = BudgetedRegionConstraint(
            Dict{String, Vector{Int}}(
                "A" => Int[],
                "B" => Int[],
            ),
            pack_requirements,
            strict_caps,
            "county",
            "county_total_budget3_pack_budget1_cap_budget1",
            1.0,
            3,
            1,
            1,
            :fixed,
        )

        @test satisfies_constraint(
            brc_fixed_pass,
            all_districts,
            regions_to_dists,
            dists_to_regions,
        )

        @test !satisfies_constraint(
            brc_fixed_total_too_small,
            all_districts,
            regions_to_dists,
            dists_to_regions,
        )

        @test !satisfies_constraint(
            brc_fixed_pack_too_small,
            all_districts,
            regions_to_dists,
            dists_to_regions,
        )

        @test !satisfies_constraint(
            brc_fixed_cap_too_small,
            all_districts,
            regions_to_dists,
            dists_to_regions,
        )
    end
end
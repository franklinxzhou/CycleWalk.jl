import MetropolizedForestRecom

name = "BudgetedRegionConstraint MFR translation"

function dummy_brc(
    pack_budget::Int,
    cap_budget::Int,
    budget_mode::Symbol,
)::BudgetedRegionConstraint
    return BudgetedRegionConstraint(
        Dict{String, Vector{Int}}(),
        Dict{String, Int}(),
        Dict{String, Int}(),
        "county",
        "dummy",
        1.0,
        pack_budget + cap_budget,
        pack_budget,
        cap_budget,
        budget_mode,
    )
end

function translated_budget_pair(brc::BudgetedRegionConstraint)
    mfr_constraints = CycleWalk.to_mfr_constraints(brc, small_square_graph)

    missing_constraints = [
        c for c in mfr_constraints
        if c isa MetropolizedForestRecom.MaxTotalMissingPackedDistsInCoarseNodes
    ]

    excess_constraints = [
        c for c in mfr_constraints
        if c isa MetropolizedForestRecom.MaxTotalExcessDistsInCoarseNodes
    ]

    @test length(missing_constraints) == 1
    @test length(excess_constraints) == 1

    missing_constraint = only(missing_constraints)
    excess_constraint = only(excess_constraints)

    return (
        missing_constraint.max_total_missing,
        excess_constraint.max_total_excess,
    )
end

@testset "$name" begin
    @testset "cap_only means strict pack and budgeted cap" begin
        brc = dummy_brc(0, 6, :cap_only)

        pack_budget, cap_budget = translated_budget_pair(brc)

        @test pack_budget == 0
        @test cap_budget == 6
    end

    @testset "pack_only means budgeted pack and strict cap" begin
        brc = dummy_brc(6, 0, :pack_only)

        pack_budget, cap_budget = translated_budget_pair(brc)

        @test pack_budget == 6
        @test cap_budget == 0
    end

    @testset "fixed keeps the chosen budget split" begin
        brc = dummy_brc(2, 4, :fixed)

        pack_budget, cap_budget = translated_budget_pair(brc)

        @test pack_budget == 2
        @test cap_budget == 4
    end
end
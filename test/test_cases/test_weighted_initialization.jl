name = "weighted initialization"

@testset "$name" begin
    graph_json = joinpath(testdir, "test_graphs", "4x4pct_2x2cnty.json")
    node_data = Set(["county", "pct", "pop", "area", "border_length"])

    base_graph = BaseGraph(
        graph_json,
        "pop";
        inc_node_data = node_data,
        area_col = "area",
        node_border_col = "border_length",
        edge_perimeter_col = "length",
    )

    graph = MultiLevelGraph(base_graph, ["county", "pct"])

    constraints = initialize_constraints()
    add_constraint!(constraints, PopulationConstraint(4, 4))

    num_dists = 4

    @testset "default uniform initializer lifts assignment keys" begin
        rng = PCG.PCGStateOneseq(UInt64, 20260621)

        partition = LinkCutPartition(
            graph,
            constraints,
            num_dists;
            rng = rng,
        )

        @test partition isa LinkCutPartition
        @test partition.num_dists == num_dists
        @test satisfies_constraints(partition, constraints; check_population = true)
    end

    @testset "explicit BoundaryWeightedInitializer lifts assignment keys" begin
        rng = PCG.PCGStateOneseq(UInt64, 20260619)

        partition = LinkCutPartition(
            graph,
            constraints,
            num_dists;
            rng = rng,
            initializer = BoundaryWeightedInitializer(50.0, 10.0, 1.0),
            initializer_levels = ["county", "pct"],
        )

        @test partition isa LinkCutPartition
        @test partition.num_dists == num_dists
        @test satisfies_constraints(partition, constraints; check_population = true)
    end

    @testset "init_mode boundary_weighted lifts assignment keys" begin
        rng = PCG.PCGStateOneseq(UInt64, 20260620)

        partition = LinkCutPartition(
            graph,
            constraints,
            num_dists;
            rng = rng,
            init_mode = :boundary_weighted,
            init_county_cut_weight = 50.0,
            init_mcd_cut_weight = 10.0,
            init_fine_cut_weight = 1.0,
            initializer_levels = ["county", "pct"],
        )

        @test partition isa LinkCutPartition
        @test partition.num_dists == num_dists
        @test satisfies_constraints(partition, constraints; check_population = true)
    end

    @testset "invalid init_mode errors" begin
        rng = PCG.PCGStateOneseq(UInt64, 20260622)

        @test_throws ArgumentError LinkCutPartition(
            graph,
            constraints,
            num_dists;
            rng = rng,
            init_mode = :not_a_real_initializer,
        )
    end
end
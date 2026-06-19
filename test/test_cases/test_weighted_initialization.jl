name = "weighted initialization"

@testset "$name" begin
    graph_json = joinpath(testdir, "test_graphs", "4x4pct_2x2cnty.json")
    node_data = Set(["pct", "pop", "area", "border_length"])

    base_graph = BaseGraph(
        graph_json,
        "pop";
        inc_node_data = node_data,
        area_col = "area",
        node_border_col = "border_length",
        edge_perimeter_col = "length",
    )

    # Important:
    # Use a one-level graph here. With only a PopulationConstraint, the
    # MFR initializer internally builds a one-level assignment keyed by
    # tuples like ("1,3",). The original CycleWalk graph must therefore
    # also be one-level, or the rewrap step will see the wrong key shape.
    
    graph = Graph(base_graph, ["pct"])

    constraints = initialize_constraints()
    add_constraint!(constraints, PopulationConstraint(4, 4))

    @testset "explicit BoundaryWeightedInitializer object" begin
        rng = PCG.PCGStateOneseq(UInt64, 20260619)

        partition = LinkCutPartition(
            graph,
            constraints,
            4;
            rng = rng,
            initializer = BoundaryWeightedInitializer(50.0, 10.0, 1.0),
        )

        @test partition isa LinkCutPartition
        @test partition.num_dists == 4
        @test satisfies_constraints(partition, constraints; check_population = true)
    end

    @testset "init_mode keyword path" begin
        rng = PCG.PCGStateOneseq(UInt64, 20260620)

        partition = LinkCutPartition(
            graph,
            constraints,
            4;
            rng = rng,
            init_mode = :boundary_weighted,
            init_county_cut_weight = 50.0,
            init_mcd_cut_weight = 10.0,
            init_fine_cut_weight = 1.0,
        )

        @test partition isa LinkCutPartition
        @test partition.num_dists == 4
        @test satisfies_constraints(partition, constraints; check_population = true)
    end

    @testset "default remains uniform" begin
        rng = PCG.PCGStateOneseq(UInt64, 20260621)

        partition = LinkCutPartition(
            graph,
            constraints,
            4;
            rng = rng,
        )

        @test partition isa LinkCutPartition
        @test partition.num_dists == 4
        @test satisfies_constraints(partition, constraints; check_population = true)
    end
end
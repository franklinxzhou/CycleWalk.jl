
using CycleWalk
using RandomNumbers
using Test

const testdir = dirname(@__FILE__)


function is_close(a,b)
    if a > 0.01
        0.9 <= a/b && a/b <= 1.1
    else 
        0.6 <= a/b && a/b <= 1.4
    end 
end


function get_observed_cut_edges(
    graph::MultiLevelGraph, 
    constraints::Dict,
    num_districts::Int, 
    measure::Measure=Measure();
    cycle_steps::Int=50_000,
    cycle_walk_frac::Float64 = 0.1,
    cut_edge_field = "connections"
)::Dict
    rng = PCG.PCGStateOneseq(UInt64, 1241909)
    initial_partition = MultiLevelPartition(graph, constraints, num_districts; 
                                            rng=rng);
    partition = LinkCutPartition(initial_partition, rng);

    cycle_walk = build_lifted_tree_cycle_walk(constraints)
    internal_walk = build_internal_forest_walk(constraints)
    proposal = [(cycle_walk_frac, cycle_walk), 
                (1.0-cycle_walk_frac, internal_walk)]
         
    instep = Int(floor(1.0/cycle_walk_frac))
    edge_cut_counts = Dict{Int64, Int64}()
    for ii = 1:cycle_steps
        run_metropolis_hastings!(partition, proposal, measure, instep, rng);
        cut_edges = get_cut_edge_sum(partition, column=cut_edge_field)
        edge_cut_counts[cut_edges] = get(edge_cut_counts, cut_edges, 0) + 1
    end

    return edge_cut_counts
end 



small_square_json = joinpath("test_graphs", "4x4pct_2x2cnty.json")
small_square_node_data = Set(["county", "pct", "pop", "area", "border_length"])
small_square_base_graph = BaseGraph(small_square_json, "pop", 
                                    inc_node_data=small_square_node_data,
                                    area_col="area",
                                    node_border_col="border_length", 
                                    edge_perimeter_col="length")
small_square_graph = MultiLevelGraph(small_square_base_graph, ["pct"])


include(joinpath(testdir, "test_linkcuttree.jl"))
include(joinpath(testdir, "test_docs_coverage.jl"))

tests = [
    "small_square_p88_unweighted",
    "small_square_p88_weighted",
    "small_square_p88_polsby_popper",
    ]
@testset verbose = true "CycleWalk Tests" begin
    for t in tests
        tp = joinpath(testdir, "test_cases","$(t).jl")
        include(tp)
    end
end;

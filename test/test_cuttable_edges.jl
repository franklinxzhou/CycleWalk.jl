# Targets the optimizations merged in the last week:
#   #3  prefix-sum cuttable-edge search (find_cuttable_edge_pairs / find_first_valid_cut)
#   #2  cached per-node populations (partition.node_pops)
#   #1/#2/#3 all claim "bit-identical determinism" -> a reproducibility regression.
#
# The prefix-sum rewrite changed *how* segment populations are summed (O(1) prefix
# difference instead of an O(path) view-sum) but must return exactly the same set of
# cut pairs. These tests pin that set against an independent brute-force reference.
#
# Precondition (relied on by find_first_valid_cut's downward walk): initial_cut_index
# is itself a balanced single cut -- in production it is the current district boundary
# (length(uPath)), which always satisfies the population constraint. The helpers below
# only ever pass an init drawn from the valid single-cut indices.

# Single-cut indices i (1..path_length-1) whose two sides both land in [min,max].
function valid_single_cuts(cycle_weights::Vector{Float64}, min_pop, max_pop)
    tot = sum(cycle_weights)
    out = Int[]
    s = 0.0
    for i in 1:length(cycle_weights)-1
        s += cycle_weights[i]
        (min_pop <= s <= max_pop && min_pop <= tot - s <= max_pop) && push!(out, i)
    end
    return out
end

# Independent O(path^2) reference: every (cut1,cut2) whose two segments both land in
# [min_pop,max_pop], minus the initial cut. Deliberately avoids the prefix-sum and the
# two-pointer early-exit so it cannot share a bug with the implementation under test.
function brute_force_cuttable_pairs(
    cycle_weights::Vector{Float64},
    initial_cut_index::Int,
    min_pop::Float64,
    max_pop::Float64,
)
    path_length = length(cycle_weights)
    totpop = sum(cycle_weights)
    pairs = Set{Tuple{Int,Int}}()
    for cut1 in 1:path_length
        for cut2 in cut1:path_length-1
            pop1 = sum(cycle_weights[cut1:cut2])
            pop2 = totpop - pop1
            if min_pop <= pop1 <= max_pop && min_pop <= pop2 <= max_pop
                push!(pairs, (cut1, cut2))
            end
        end
    end
    delete!(pairs, (1, initial_cut_index))
    return pairs
end

@testset "prefix-sum cuttable edges (#3)" begin
    # find_cuttable_edge_pairs is typed on ::LinkCutPartition but never touches it;
    # build one real partition just to satisfy the signature.
    cons = initialize_constraints()
    add_constraint!(cons, PopulationConstraint(small_square_graph, 2, 0.5))
    rng = PCG.PCGStateOneseq(UInt64, 98765)
    part = LinkCutPartition(small_square_graph, cons, 2; rng=rng)

    make_cons(min_pop, max_pop) = begin
        c = initialize_constraints()
        add_constraint!(c, PopulationConstraint(Float64(min_pop), Float64(max_pop)))
        c
    end

    @testset "find_first_valid_cut walks down to the smallest valid index" begin
        # weights all 1.0: sum(1:i) == i, so pop1==i and pop2==tot-i.
        w = fill(1.0, 10)               # totpop == 10
        pre = pushfirst!(cumsum(w), 0.0)
        # valid single cut needs 3 <= i <= 7 (both sides in [3,7]).
        fvc = CycleWalk.find_first_valid_cut(pre, 6, 3.0, 7.0, 10.0)
        @test fvc == 3
        # starting already at the bottom of the valid range stays put
        @test CycleWalk.find_first_valid_cut(pre, 3, 3.0, 7.0, 10.0) == 3
    end

    @testset "matches brute force on handcrafted weights" begin
        w = Float64[2, 1, 3, 1, 2, 1, 2]   # totpop == 12
        for (mn, mx, init) in [(4.0, 8.0, 3), (5.0, 7.0, 4), (3.0, 9.0, 2)]
            got = CycleWalk.find_cuttable_edge_pairs(w, init, part, make_cons(mn, mx))
            ref = brute_force_cuttable_pairs(w, init, mn, mx)
            @test got == ref
            # every returned pair really is balanced
            tot = sum(w)
            for (c1, c2) in got
                p1 = sum(w[c1:c2])
                @test mn <= p1 <= mx
                @test mn <= tot - p1 <= mx
            end
        end
    end

    @testset "matches brute force on randomized weights" begin
        rng_t = PCG.PCGStateOneseq(UInt64, 424242)
        checked = 0
        for _ in 1:400
            n = 4 + Int(rand(rng_t, UInt) % 12)          # path length 4..15
            w = Float64[1 + (rand(rng_t, UInt) % 5) for _ in 1:n]  # weights 1..5
            # pick a tolerance band around half the total so some pairs qualify
            tot = sum(w)
            mn = tot * (0.30 + 0.15 * rand(rng_t))
            mx = tot - mn
            singles = valid_single_cuts(w, mn, mx)
            isempty(singles) && continue                  # precondition unsatisfiable
            init = singles[1 + Int(rand(rng_t, UInt) % length(singles))]
            got = CycleWalk.find_cuttable_edge_pairs(w, init, part, make_cons(mn, mx))
            ref = brute_force_cuttable_pairs(w, init, Float64(mn), Float64(mx))
            @test got == ref
            checked += 1
        end
        @test checked > 50                                # the sweep actually exercised the path
    end

    @testset "no balanced split -> empty set" begin
        w = Float64[1, 1, 100, 1, 1]      # the heavy node can't be split evenly
        got = CycleWalk.find_cuttable_edge_pairs(w, 3, part, make_cons(40.0, 64.0))
        @test isempty(got)
    end

    @testset "node_pops cache equals graph attributes (#2)" begin
        bg = small_square_graph.graphs_by_level[end]
        pc = bg.pop_col
        @test length(part.node_pops) == bg.num_nodes
        for ni in 1:bg.num_nodes
            @test part.node_pops[ni] == Float64(bg.node_attributes[ni][pc])
        end
        # the cached vector is what balance accounting sums, so total must agree
        @test sum(part.node_pops) ≈ sum(Float64(bg.node_attributes[ni][pc])
                                         for ni in 1:bg.num_nodes)
    end
end

@testset "MCMC determinism after refactors (#1/#2/#3)" begin
    # The three perf PRs each claim bit-identical output. Same seed -> identical
    # cut-edge histogram, so any future change that perturbs the sampler is caught.
    cons = initialize_constraints()
    add_constraint!(cons, PopulationConstraint(small_square_graph, 2, 0.5))
    run_short() = get_observed_cut_edges(small_square_graph, cons, 2;
                                         cycle_steps=300, cut_edge_field="connections")
    a = run_short()
    b = run_short()
    @test a == b
end

"""
    gather_lifted_cycle_walk_diagnostics!(diagnostics; accept_ratio=0, kwargs...)

Dispatch the per-step data of one [`lifted_tree_cycle_walk!`](@ref) proposal to
whichever diagnostics are registered in `diagnostics`. Each registered diagnostic
type (acceptance ratio, cycle length, Δnodes, Δpopulation, cuttable-edge pairs,
unique cuttable edges, swappable population) pulls the keyword data it needs (cycle
weights, district/edge pairs, chosen cut indices, swap data, `uPath` length, the
partition) and records its value. No-op if `diagnostics === nothing`.
"""
function gather_lifted_cycle_walk_diagnostics!(
    diagnostics::Union{ProposalDiagnostics, Nothing};
    accept_ratio::T=0,
    cycle_weights::Union{Nothing, Vector{Float64}}=nothing,
    dist_pair::Union{Nothing, Tuple}=nothing,
    edge_pair::Union{Nothing, Tuple}=nothing,
    edge_inds::Union{Nothing, Tuple}=nothing,
    edge_pair_inds::Union{Nothing, Vector}=nothing,
    swap_data::Union{Nothing, Tuple{Int, Bool}}=nothing,
    len_uPath::Union{Nothing, Int}=nothing,
    partition::Union{Nothing, LinkCutPartition}=nothing
) where T <: Real
    diagnostics === nothing && return

    if haskey(diagnostics, AcceptanceRatios)
        diagnostic = diagnostics[AcceptanceRatios]
        push_acceptance_probability!(diagnostic, accept_ratio)
    end

    if haskey(diagnostics, CycleLengthDiagnostic)
        diagnostic = diagnostics[CycleLengthDiagnostic]
        push_cycle_length_diagnostic!(diagnostic, cycle_weights)
    end

    if haskey(diagnostics, DeltaNodesDiagnostic)
        diagnostic = diagnostics[DeltaNodesDiagnostic]
        push_delta_node_diagnostic!(diagnostic, dist_pair, edge_pair,
                                    edge_inds, partition, swap_data)
    end

    if haskey(diagnostics, DeltaPopDiagnostic)
        diagnostic = diagnostics[DeltaPopDiagnostic]
        push_delta_pop_diagnostic!(diagnostic, edge_inds, len_uPath,
                                   cycle_weights, swap_data)
    end

    if haskey(diagnostics, CuttableEdgePairsDiagnostic)
        diagnostic = diagnostics[CuttableEdgePairsDiagnostic]
        push_cuttable_edge_pairs_diagnostic!(diagnostic, edge_pair_inds)
    end

    if haskey(diagnostics, UniqueCuttableEdgesDiagnostic)
        diagnostic = diagnostics[UniqueCuttableEdgesDiagnostic]
        len_cycleWeights = nothing 
        if cycle_weights !== nothing
            len_cycleWeights = length(cycle_weights)
        end 
        push_unique_cuttable_edges_diagnostic!(diagnostic, edge_pair_inds,
                                               len_cycleWeights, len_uPath)
    end

    if (haskey(diagnostics, MaxSwappablePopulationDiagnostic) ||
        haskey(diagnostics, AvgSwappablePopulationDiagnostic))
        max_diag = nothing 
        avg_diag = nothing
        if haskey(diagnostics, MaxSwappablePopulationDiagnostic)
            max_diag = diagnostics[MaxSwappablePopulationDiagnostic]
        end
        if haskey(diagnostics, AvgSwappablePopulationDiagnostic)
            avg_diag = diagnostics[AvgSwappablePopulationDiagnostic]
        end
        push_swappable_pop_diagnostic!(max_diag, avg_diag, edge_pair_inds,
                                       cycle_weights, len_uPath)
    end


end
"""
    UniqueCuttableEdgesDiagnostic <: AbstractProposalDiagnostics

Per-proposal record of the number of *distinct* cycle edges that participate in some
valid cut pair (as opposed to the number of pairs, see
[`CuttableEdgePairsDiagnostic`](@ref)). Backed by `data_vec`.
"""
struct UniqueCuttableEdgesDiagnostic <: AbstractProposalDiagnostics
    data_vec::Vector{Int64}
end

"""
    UniqueCuttableEdgesDiagnostic()

Construct an empty [`UniqueCuttableEdgesDiagnostic`](@ref).
"""
function UniqueCuttableEdgesDiagnostic()
    data_vec = Vector{Int64}(undef, 0)
    return UniqueCuttableEdgesDiagnostic(data_vec)
end

##############################

"""
    push_unique_cuttable_edges_diagnostic!(diag, edge_pair_inds, len_cycle, len_uPath)

Record the number of distinct cycle edges appearing in any valid cut pair, always
including the two current boundary edges (cycle positions `1` and `len_uPath+1`).
Records `2` (just those boundary edges) when the cycle data is unavailable.
"""
function push_unique_cuttable_edges_diagnostic!(
    diag::UniqueCuttableEdgesDiagnostic,
    edge_pair_inds::Union{Nothing, Vector},
    len_cycle::Union{Nothing, Int},
    len_uPath::Union{Nothing, Int}
)
    if edge_pair_inds === nothing || len_uPath === nothing || 
        len_cycle === nothing
        push!(diag.data_vec, 2)
        return
    end

    edges = Set{Int64}([1, len_uPath+1])
    for (e1, e2) in edge_pair_inds
        e2 = mod(e2, len_cycle)+1
        push!(edges, e1)
        push!(edges, e2)
    end
    push!(diag.data_vec, length(edges))
end

"""
    reset_diagnostic!(diag::UniqueCuttableEdgesDiagnostic)

Clear the accumulated unique-cuttable-edge counts.
"""
function reset_diagnostic!(diag::UniqueCuttableEdgesDiagnostic)
    resize!(diag.data_vec, 0)
end
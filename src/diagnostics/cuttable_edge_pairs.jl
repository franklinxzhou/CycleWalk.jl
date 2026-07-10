"""
    CuttableEdgePairsDiagnostic <: AbstractProposalDiagnostics

Per-proposal record of the number of population-balanced cut pairs available on each
2-tree cycle walk (i.e. how many distinct valid moves the proposal could choose
from). Backed by `data_vec`.
"""
struct CuttableEdgePairsDiagnostic <: AbstractProposalDiagnostics
    data_vec::Vector{Int64}
end

"""
    CuttableEdgePairsDiagnostic()

Construct an empty [`CuttableEdgePairsDiagnostic`](@ref).
"""
function CuttableEdgePairsDiagnostic()
    data_vec = Vector{Int64}(undef, 0)
    return CuttableEdgePairsDiagnostic(data_vec)
end

##############################

"""
    push_cuttable_edge_pairs_diagnostic!(diag, edge_pair_inds)

Record the number of valid cut pairs for one proposal: `length(edge_pair_inds)+1`
(the candidate pairs plus the current cut), or `1` when no alternative pairs were
found (`edge_pair_inds === nothing`).
"""
function push_cuttable_edge_pairs_diagnostic!(
    diag::CuttableEdgePairsDiagnostic,
    edge_pair_inds::Union{Nothing, Vector}
)
    if edge_pair_inds === nothing 
        push!(diag.data_vec, 1)
    else 
        push!(diag.data_vec, length(edge_pair_inds)+1)
    end
end

"""
    reset_diagnostic!(diag::CuttableEdgePairsDiagnostic)

Clear the accumulated cut-pair counts.
"""
function reset_diagnostic!(diag::CuttableEdgePairsDiagnostic)
    resize!(diag.data_vec, 0)
end
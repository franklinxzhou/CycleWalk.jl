"""
    DeltaPopDiagnostic <: AbstractProposalDiagnostics

Per-proposal record of the population moved between districts by each proposed 2-tree
cycle walk, stored as a fraction of the two districts' combined population. Backed by
`data_vec`.
"""
struct DeltaPopDiagnostic <: AbstractProposalDiagnostics
    data_vec::Vector{Float64}
end

"""
    DeltaPopDiagnostic()

Construct an empty [`DeltaPopDiagnostic`](@ref).
"""
function DeltaPopDiagnostic()
    data_vec = Vector{Float64}(undef, 0)
    return DeltaPopDiagnostic(data_vec)
end

"""
    push_delta_pop_diagnostic!(del_pop_diag, edge_inds, len_uPath, cycle_weights, swap_data)

Compute and record the fraction of the cycle's total population that the proposed cut
reassigns between the two districts (resolving the assignment swap from `swap_data`).
Records `0` when the proposal carried no move (any of the inputs `nothing`).
"""
function push_delta_pop_diagnostic!(
    del_pop_diag::DeltaPopDiagnostic,
    edge_inds::Union{Nothing, Tuple}=nothing,
    len_uPath::Union{Nothing, T}=nothing,
    cycle_weights::Union{Nothing, Vector}=nothing,
    swap_data::Union{Nothing, Tuple{T, Bool}}=nothing
) where T<:Int
    if (edge_inds === nothing || cycle_weights === nothing || 
        len_uPath === nothing)
        push!(del_pop_diag.data_vec, 0)
        return
    end

    proposed_cut = edge_inds
    overlap1 = 0
    tot_pop = sum(cycle_weights)
    if proposed_cut[1] <= len_uPath
        overlap1 += sum(cycle_weights[proposed_cut[1]:min(len_uPath,
                                                          proposed_cut[2])])
    elseif proposed_cut[1] > len_uPath+1
        overlap1 += sum(cycle_weights[len_uPath+1:proposed_cut[1]-1])
    end
    if proposed_cut[2] < length(cycle_weights)
        overlap1 += sum(cycle_weights[max(len_uPath+1, 
                                                 proposed_cut[2]+1):end])
    end

    path_ind_l11, swap_link11 = swap_data
    l11_cur = path_ind_l11 <= len_uPath
    l11_proposed = (proposed_cut[1] <= path_ind_l11 <= proposed_cut[2])
    delta_pop = overlap1
    if swap_data === nothing
        delta_pop = min(overlap1, tot_pop-overlap1)
    elseif (l11_cur ⊻ l11_proposed) ⊻ !swap_link11
        delta_pop = tot_pop-overlap1
    end
    push!(del_pop_diag.data_vec, delta_pop/tot_pop)
end

"""
    reset_diagnostic!(del_pop_diag::DeltaPopDiagnostic)

Clear the accumulated population-delta fractions.
"""
function reset_diagnostic!(del_pop_diag::DeltaPopDiagnostic)
    resize!(del_pop_diag.data_vec, 0)
end


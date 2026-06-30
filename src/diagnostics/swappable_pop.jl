"""
    MaxSwappablePopulationDiagnostic <: AbstractProposalDiagnostics

Per-proposal record of the *largest* population fraction that any valid cut of the
proposal's cycle could swap between districts. Backed by `data_vec`.
"""
struct MaxSwappablePopulationDiagnostic <: AbstractProposalDiagnostics
    data_vec::Vector{Float64}
end

"""
    MaxSwappablePopulationDiagnostic()

Construct an empty [`MaxSwappablePopulationDiagnostic`](@ref).
"""
function MaxSwappablePopulationDiagnostic()
    data_vec = Vector{Float64}(undef, 0)
    return MaxSwappablePopulationDiagnostic(data_vec)
end

"""
    AvgSwappablePopulationDiagnostic <: AbstractProposalDiagnostics

Per-proposal record of the *average* swappable population fraction over the valid
cuts of the proposal's cycle. Backed by `data_vec`.
"""
struct AvgSwappablePopulationDiagnostic <: AbstractProposalDiagnostics
    data_vec::Vector{Float64}
end

"""
    AvgSwappablePopulationDiagnostic()

Construct an empty [`AvgSwappablePopulationDiagnostic`](@ref).
"""
function AvgSwappablePopulationDiagnostic()
    data_vec = Vector{Float64}(undef, 0)
    return AvgSwappablePopulationDiagnostic(data_vec)
end

"""
    push_swappable_pop_diagnostic!(max_diag, avg_diag, edge_pair_inds, cycle_weights, len_uPath)

For each valid cut pair, compute the population fraction it would swap (the smaller of
the two induced sides), then record the maximum into `max_diag` and the mean into
`avg_diag` (whichever are non-`nothing`). Records `0` when the cycle data is
unavailable.
"""
function push_swappable_pop_diagnostic!(
    max_diag::Union{Nothing, MaxSwappablePopulationDiagnostic},
    avg_diag::Union{Nothing, AvgSwappablePopulationDiagnostic},
    edge_pair_inds::Union{Nothing, Vector},
    cycle_weights::Union{Nothing, Vector},
    len_uPath::Union{Nothing, Int}
)
    if edge_pair_inds === nothing || len_uPath === nothing || 
        cycle_weights === nothing
        if max_diag !== nothing
            push!(max_diag.data_vec, 0)
        end
        if avg_diag !== nothing
            push!(avg_diag.data_vec, 0)
        end
        return
    end

    max_swap = 0
    avg_swap = 0
    tot_pop = sum(cycle_weights)
    for (e1, e2) in edge_pair_inds
        pop_swap1 = 0
        if e1 <= len_uPath
            pop_swap1 += sum(cycle_weights[e1:min(len_uPath,e2)])
        elseif e1 > len_uPath+1
            pop_swap1 += sum(cycle_weights[len_uPath+1:e1-1])
        end
        if e2 < length(cycle_weights)
            pop_swap1 += sum(cycle_weights[max(len_uPath+1, e2+1):end])
        end
        pop_swap = min(pop_swap1, tot_pop-pop_swap1)
        max_swap = max(max_swap, pop_swap)
        avg_swap += pop_swap
    end
    avg_swap /= (length(edge_pair_inds)+1)*tot_pop
    max_swap /= tot_pop
    if max_diag !== nothing
        push!(max_diag.data_vec, max_swap)
    end
    if avg_diag !== nothing
        push!(avg_diag.data_vec, avg_swap)
    end
end

"""
    reset_diagnostic!(diag::MaxSwappablePopulationDiagnostic)

Clear the accumulated max-swappable-population fractions.
"""
function reset_diagnostic!(diag::MaxSwappablePopulationDiagnostic)
    resize!(diag.data_vec, 0)
end

"""
    reset_diagnostic!(diag::AvgSwappablePopulationDiagnostic)

Clear the accumulated avg-swappable-population fractions.
"""
function reset_diagnostic!(diag::AvgSwappablePopulationDiagnostic)
    resize!(diag.data_vec, 0)
end
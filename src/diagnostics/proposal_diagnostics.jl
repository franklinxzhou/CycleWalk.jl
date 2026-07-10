"""
    get_proposal_diagnostics(run_diagnostics, proposal)

Return the [`ProposalDiagnostics`](@ref) registered for `proposal`, or `nothing` if
that proposal has no diagnostics. Called each MCMC step to fetch the diagnostics to
gather for the chosen proposal.
"""
function get_proposal_diagnostics(
    run_diagnostics::RunDiagnostics,
    proposal::Function
)::Union{Nothing, ProposalDiagnostics}
    if !haskey(run_diagnostics, proposal)
        return nothing
    end
    return run_diagnostics[proposal][end]
end

"""
    push_diagnostic!(run_diagnostics, proposal, proposal_diagnostic; desc=string(proposal))

Register `proposal_diagnostic` to be gathered for `proposal` during a run, creating
the proposal's [`ProposalDiagnostics`](@ref) entry (labeled `desc`) if needed. Keyed
by the diagnostic's type, so re-registering the same type replaces it.
"""
function push_diagnostic!(
    run_diagnostics::RunDiagnostics,
    proposal::Function,
    proposal_diagnostic::PD;
    desc::String = string(proposal)
) where PD <: AbstractProposalDiagnostics
    if !haskey(run_diagnostics, proposal)
        run_diagnostics[proposal] = (desc, ProposalDiagnostics())
    end
    proposal_diagnostics = run_diagnostics[proposal][2]
    proposal_diagnostics[typeof(proposal_diagnostic)] = proposal_diagnostic
end

"""
    push_acceptance_probability!(acceptance_ratios, p_accept)

Append an acceptance probability `p_accept` to the [`AcceptanceRatios`](@ref) record.
"""
function push_acceptance_probability!(
    acceptance_ratios::AcceptanceRatios,
    p_accept::Real
)
    push!(acceptance_ratios.data_vec, p_accept)
end

"""
    update_acceptance_ratio_diagnostic!(proposal_diagnostics, acceptance_ratio)

Overwrite the most recently recorded acceptance ratio with the corrected
`acceptance_ratio` (the proposal ratio times the energy factor). No-op if
`proposal_diagnostics` is `nothing` or has no [`AcceptanceRatios`](@ref).
"""
function update_acceptance_ratio_diagnostic!(
    proposal_diagnostics::Union{ProposalDiagnostics, Nothing},
    acceptance_ratio::Float64
)
    proposal_diagnostics === nothing && return
    !haskey(proposal_diagnostics, AcceptanceRatios) && return
    
    acceptance_ratios = proposal_diagnostics[AcceptanceRatios]
    acceptance_ratios.data_vec[end] = acceptance_ratio
end

"""
    reset_diagnostic!(acceptance_ratios::AcceptanceRatios)

Clear the accumulated acceptance ratios (called after each output flush so the buffer
holds only the data for the next output window).
"""
function reset_diagnostic!(acceptance_ratios::AcceptanceRatios)
    resize!(acceptance_ratios.data_vec, 0)
end

##############################

"""
    push_cycle_length_diagnostic!(cycle_len_diag, cycle_weights)

Record the length of the proposed cycle (the number of `cycle_weights`, or `0` when
no cycle was formed) into the [`CycleLengthDiagnostic`](@ref).
"""
function push_cycle_length_diagnostic!(
    cycle_len_diag::CycleLengthDiagnostic,
    cycle_weights::Union{Nothing, Vector{Float64}}
)
    len = 0
    if cycle_weights !== nothing
        len = length(cycle_weights)
    end
    push!(cycle_len_diag.data_vec, len)
end

"""
    reset_diagnostic!(cycle_len_diag::CycleLengthDiagnostic)

Clear the accumulated cycle lengths.
"""
function reset_diagnostic!(cycle_len_diag::CycleLengthDiagnostic)
    resize!(cycle_len_diag.data_vec, 0)
end

##############################


"""
    reset_diagnostics!(diagnostics::ProposalDiagnostics)

Reset every diagnostic of a single proposal by dispatching to its
[`reset_diagnostic!`](@ref).
"""
function reset_diagnostics!(
    diagnostics::ProposalDiagnostics
)
    for diagnostic in values(diagnostics)
        reset_diagnostic!(diagnostic)
    end
end

"""
    reset_diagnostics!(diagnostics::RunDiagnostics)

Reset the diagnostics of every proposal in the run. Called after each output flush.
"""
function reset_diagnostics!(
    diagnostics::RunDiagnostics
)
    for proposal in keys(diagnostics)
        desc, proposal_diagnostics = diagnostics[proposal]
        reset_diagnostics!(proposal_diagnostics)
    end
end 

"""
    gather_diagnostics!(diagnostics, proposal, p_accept)

Generic per-step diagnostic hook: if `proposal` has an [`AcceptanceRatios`](@ref)
diagnostic registered, append `p_accept` to it. (Proposal-specific diagnostics are
gathered by dedicated gatherers such as
[`gather_lifted_cycle_walk_diagnostics!`](@ref).)
"""
function gather_diagnostics!(
    diagnostics::RunDiagnostics,
    proposal::Function,
    p_accept::Real
)
    !haskey(diagnostics, proposal) && return
    desc, proposal_diagnostics = diagnostics[proposal]

    if haskey(proposal_diagnostics, AcceptanceRatios)
        diagnostic = proposal_diagnostics[AcceptanceRatios]
        push_acceptance_probability!(diagnostic, p_accept)
    end
end

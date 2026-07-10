"""
    AbstractProposalDiagnostics

Supertype for per-proposal diagnostics. Each concrete type wraps a `data_vec` that
accumulates one value per proposal between output flushes, and implements
`reset_diagnostic!` (and a `push_..._diagnostic!` recorder).
"""
abstract type AbstractProposalDiagnostics end

"""
    ProposalDiagnostics

`Dict` mapping a diagnostic type to its instance — the set of diagnostics gathered for
a single proposal.
"""
ProposalDiagnostics = Dict{Type{T} where T<:AbstractProposalDiagnostics,
                           AbstractProposalDiagnostics}

"""
    RunDiagnostics

`Dict` mapping each proposal function to `(description, ProposalDiagnostics)` — the
top-level container passed to [`run_metropolis_hastings!`](@ref). Populate it with
[`push_diagnostic!`](@ref).
"""
RunDiagnostics = Dict{Function, Tuple{String, ProposalDiagnostics}}

"""
    AcceptanceRatios <: AbstractProposalDiagnostics

Diagnostic recording the (energy-corrected) acceptance probability of each proposal.
"""
struct AcceptanceRatios <: AbstractProposalDiagnostics
    data_vec::Vector{Float64}
end


"""
    AcceptanceRatios()

Construct an empty [`AcceptanceRatios`](@ref) diagnostic.
"""
function AcceptanceRatios()
    data_vec = Vector{Float64}(undef, 0)
    return AcceptanceRatios(data_vec)
end


"""
    CycleLengthDiagnostic <: AbstractProposalDiagnostics

Diagnostic recording the length of the cycle formed by each 2-tree cycle-walk
proposal.
"""
struct CycleLengthDiagnostic <: AbstractProposalDiagnostics
    data_vec::Vector{Int64}
end


"""
    CycleLengthDiagnostic()

Construct an empty [`CycleLengthDiagnostic`](@ref).
"""
function CycleLengthDiagnostic()
    data_vec = Vector{Int64}(undef, 0)
    return CycleLengthDiagnostic(data_vec)
end



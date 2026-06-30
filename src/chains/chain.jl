"""
    Chain{T <: Real}

Convenience bundle of everything a run needs: the `proposal` (a single closure or a
weighted mixture of `(weight, proposal)` pairs), the target `measure`, an optional
output `writer`, and the `rng`. Run it with [`run_chain!`](@ref).
"""
mutable struct Chain{T <: Real}
    proposal::Union{Function,Vector{Tuple{T, Function}}}
    measure::Measure
    writer::Union{Writer, Nothing}
    rng::AbstractRNG
end

"""
    Chain(proposal, measure, writer, rng)

Construct a [`Chain`](@ref) from a single proposal function (the element type is
widened to `Real`).
"""
function Chain(
	proposal::Function,
	measure::Measure,
	writer::Union{Writer, Nothing},
    rng::AbstractRNG
)
	return Chain{Real}(proposal, measure, writer, rng)
end

"""
    run_chain!(partition, chain, steps)

Run `chain` on `partition` for `steps` (a count or an `(initial, final)` range) by
delegating to [`run_metropolis_hastings!`](@ref). Wrapped in a `try`/`catch`:
returns `(0, chain.measure)` on success and `(1, chain.measure)` if the run throws.
"""
function run_chain!(
	partition::MultiLevelPartition,
	chain::Chain,
	steps::Union{Int,Tuple{Int,Int}}
)
	try
		run_metropolis_hastings!(partition, chain.proposal, chain.measure, steps, 
			                     chain.rng, writer=chain.writer)
		return 0, chain.measure
	catch e
		return 1, chain.measure
	end
end
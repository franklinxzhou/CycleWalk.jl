"""
    update_energy_data!(eData::AbstractEnergyData, partition, update)

Default fallback invoked by `update_partition!` for every cache after a move is
accepted. Does nothing; energy caches that maintain incremental state (e.g.
[`LogForestEnergyData`](@ref)) override this to commit the changed districts' proposed
values into their synced fields.
"""
function update_energy_data!(
	eData::ED,
	partition::LinkCutPartition,
	update::Update{T}
) where {ED <: AbstractEnergyData, T<:Int}
	# @show "in default energy data", typeof(eData)
	# by default, do nothing with the energy data unless the update is specified 
	return
end
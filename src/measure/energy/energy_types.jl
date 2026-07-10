"""
    AbstractEnergyData

Supertype for the per-energy caches stored in `LinkCutPartition.energy_data`. A
concrete subtype (e.g. [`LogForestEnergyData`](@ref), [`IsoperimetricData`](@ref),
[`PerformantVRAData`](@ref)) holds the quantities an energy needs to evaluate a
district incrementally, plus scratch buffers for tentatively-proposed values, and
defines an [`update_energy_data!`](@ref) method to commit an accepted move. Energies
with no cache rely on the default no-op `update_energy_data!`.
"""
abstract type AbstractEnergyData end
mutable struct BalanceData <: AbstractEnergyData
    identifier::Int64
    update_identifier::Vector{Int64}
    dist_pops::Vector{Float64}
    dist_pops_update::Vector{Float64}
end

function BalanceData(partition::LinkCutPartition)
    identifier = partition.identifier
    update_identifier = Vector{Int64}(undef, 0)
    dist_pops = zeros(Float64, partition.num_dists)
    dist_pops_update = zeros(Float64, partition.num_dists)

    pop_col = partition.graph.pop_col
    for ni in 1:partition.graph.num_nodes
        di = partition.node_to_dist[ni]
        # typed local keeps the `Any` node_attributes read from boxing the add
        pop::Float64 = partition.graph.node_attributes[ni][pop_col]
        dist_pops[di] += pop
    end

    return BalanceData(identifier, update_identifier, dist_pops,
                       dist_pops_update)
end

function update_balance_data!(
    data::BalanceData,
    partition::LinkCutPartition,
    update::Update
)
    data.update_identifier = copy(update.identifier)
    node_attr = partition.graph.node_attributes

    changed_districts = collect(update.changed_districts)
    data.dist_pops_update .= data.dist_pops
    for di in changed_districts
        data.dist_pops_update[di] = 0.0
    end

    pop_col = partition.graph.pop_col
    for ni in 1:partition.graph.num_nodes
        di = partition.node_to_dist_update[ni]
        if di in changed_districts
            pop::Float64 = node_attr[ni][pop_col]
            data.dist_pops_update[di] += pop
        end
    end
end

function satisfies_constraint(
    partition::LinkCutPartition,
    population_constraint::PopulationConstraint,
    districts::Union{Tuple{Vararg{T}}, Vector{T}} 
        = collect(1:partition.num_dists);
    update::Union{Update, Nothing}=nothing
)::Bool where T<:Int
    if !haskey(partition.energy_data, BalanceData)
        partition.energy_data[BalanceData] = BalanceData(partition)
    end
    data = partition.energy_data[BalanceData]

    if partition.identifier != data.identifier
        partition.energy_data[BalanceData] = BalanceData(partition)
        data = partition.energy_data[BalanceData]
    end
    if update !== nothing && update.identifier != data.update_identifier
        update_balance_data!(data, partition, update)
    end

    active_districts = districts
    active_dist_pops = data.dist_pops
    if update !== nothing
        active_districts = collect(update.changed_districts)
        active_dist_pops = data.dist_pops_update
    end

    return satisfies_constraint(population_constraint, active_dist_pops,
                                active_districts)
end

function satisfies_constraint(
    pop_constraint::PopulationConstraint,
    dist_pops::Vector{Float64},
    districts::Union{Tuple{Vararg{T}}, Vector{T}}
)::Bool where T<:Int
    for di in districts
        pop = dist_pops[di]
        if !(pop_constraint.min_pop <= pop <= pop_constraint.max_pop)
            return false
        end
    end
    return true
end

function update_energy_data!(
    data::BalanceData,
    partition::LinkCutPartition,
    update::Update{T}
) where T<:Int
    if update.identifier != data.update_identifier
        update_balance_data!(data, partition, update)
    end

    data.identifier = partition.identifier
    for di in update.changed_districts
        data.dist_pops[di] = data.dist_pops_update[di]
    end
end

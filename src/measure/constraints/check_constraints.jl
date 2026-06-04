""""""
function satisfies_constraints(
	partition::LinkCutPartition,
	constraints::Constraints,
	districts::Union{Tuple{Vararg{T}}, Vector{T}} 
        = collect(1:partition.num_dists);
	check_population::Bool = false,
	update::Union{Update, Nothing}=nothing
)::Bool where T<:Int
	if check_population && !satisfies_constraint(partition, 
		                                    constraints.population_constraint,
		                                    districts; update=update)
		@show "here1"
		return false
	end
	
	for constraint in constraints.constraints
		if !satisfies_constraint(partition, constraint, districts;
                                 update=update)
			@show "here2"
			return false
		end
	end
	return true
end

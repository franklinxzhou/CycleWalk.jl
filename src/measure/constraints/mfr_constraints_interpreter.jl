""""""
function interpret_constraints(constraints::Constraints, graph::Graph)
    mfr_constraints = mfr_initialize_constraints()
	mfr_add_constraint!(mfr_constraints, constraints.population_constraint)
	level_list = copy(graph.levels)
	for constraint in constraints.constraints
		if hasproperty(constraint, :region)
				push!(level_list, constraint.region)
		end
		mfr_constraint = to_mfr_constraint(constraint)
		mfr_add_constraint!(mfr_constraints, mfr_constraint)
	end
    return mfr_constraints, level_list
end

# Generic fallback (for unsupported types)
to_mfr_constraint(constraint::AbstractConstraint) = 
    error("Constraint type $(typeof(constraint)) not supported in MFR.")

# Specific implementations
to_mfr_constraint(constraint::PackRegionConstraint) = 
	parse_pack_region_constraint(constraint)
# ... etc

""""""
function parse_pack_region_constraint(constraint::PackRegionConstraint)
	node_to_packed_dists = Dict{Tuple{Vararg{String}}, Int}()
	for (node, packed_dists) in constraint.region_to_packed_dists
		node_to_packed_dists[(node,)] = packed_dists
	end
	return PackNodeConstraint(node_to_packed_dists, constraint.ideal_pop)
end
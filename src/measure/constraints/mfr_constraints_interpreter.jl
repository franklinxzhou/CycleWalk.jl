""""""
function interpret_constraints(constraints::Constraints, graph::Graph)
    mfr_constraints = mfr_initialize_constraints()
	mfr_add_constraint!(mfr_constraints, constraints.population_constraint)
	level_list = copy(graph.levels)
	for constraint in constraints.constraints
		if hasproperty(constraint, :region)
			if constraint.region ∉ level_list
				push!(level_list, constraint.region)
			end
		end
		mfr_constraint = to_mfr_constraint(constraint, graph)
		mfr_add_constraint!(mfr_constraints, mfr_constraint)
	end
    return mfr_constraints, level_list
end

# Generic fallback (for unsupported types)
to_mfr_constraint(constraint::AbstractConstraint, graph::Graph) = 
    error("Constraint type $(typeof(constraint)) not supported in MFR.")

# Specific implementations
to_mfr_constraint(constraint::PackRegionConstraint, graph::Graph) = 
	parse_pack_region_constraint(constraint)
to_mfr_constraint(constraint::CapRegionDistricts, graph::Graph) =
	parse_cap_region_constraint(constraint, graph)
# ... etc

""""""
function parse_pack_region_constraint(constraint::PackRegionConstraint)
	node_to_packed_dists = Dict{Tuple{Vararg{String}}, Int}()
	for (node, packed_dists) in constraint.region_to_packed_dists
		node_to_packed_dists[(node,)] = packed_dists
	end
	return PackNodeConstraint(node_to_packed_dists, constraint.ideal_pop)
end

""""""
function parse_cap_region_constraint(
	constraint::CapRegionDistricts,
	graph::Graph
)
	base_graph = graph.graphs_by_level[end]
	pop_col = base_graph.pop_col
	excess_splits = Set{Int}()

	for (region_name, district_cap) in constraint.region_to_dist_cap
		region_pop = 0
		for node_id in constraint.region_to_nodes[region_name]
			region_pop += base_graph.node_attributes[node_id][pop_col]
		end
		min_districts = Int(ceil(region_pop / constraint.ideal_pop))
		push!(excess_splits, district_cap - min_districts)
	end

	if isempty(excess_splits)
		return AllowedExcessDistsInCoarseNodes(0, constraint.ideal_pop)
	end

	@assert length(excess_splits) == 1 "CapRegionDistricts maps to a single AllowedExcessDistsInCoarseNodes excess_splitting value"
	excess_split = first(excess_splits)
	@assert excess_split >= 0 "Derived excess_split must be non-negative"

	return AllowedExcessDistsInCoarseNodes(excess_split, constraint.ideal_pop)
end
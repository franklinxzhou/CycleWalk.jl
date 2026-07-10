"""
    interpret_constraints(constraints, graph)

Translate a CycleWalk [`Constraints`](@ref) set into the form
`MetropolizedForestRecom` (MFR) needs to draw an initial plan. Returns
`(mfr_constraints, level_list)`: the converted MFR constraint container, and the list
of graph levels (the base levels plus any region levels referenced by region
constraints). Used by the `LinkCutPartition` constructor to seed a partition.
"""
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
		for mfr_constraint in to_mfr_constraints(constraint, graph)
			mfr_add_constraint!(mfr_constraints, mfr_constraint)
		end
	end
    return mfr_constraints, level_list
end

# `to_mfr_constraint` translates one CycleWalk constraint to a single MFR constraint;
# `to_mfr_constraints` is the list-valued form (a constraint may map to several).
# Methods are added per concrete constraint type below.

"""
    to_mfr_constraint(constraint, graph)

Translate a single CycleWalk constraint into its `MetropolizedForestRecom`
equivalent. The generic fallback errors; concrete methods are defined for the
supported constraint types.
"""
to_mfr_constraint(constraint::AbstractConstraint, graph::Graph) =
    error("Constraint type $(typeof(constraint)) not supported in MFR.")

"""
    to_mfr_constraints(constraint, graph)

List-valued translation of a CycleWalk constraint to MFR constraints. The generic
method wraps the single-output [`to_mfr_constraint`](@ref) in a one-element vector;
constraints that expand to several MFR constraints (e.g.
[`BudgetedRegionConstraint`](@ref)) add their own method.
"""
to_mfr_constraints(constraint::AbstractConstraint, graph::Graph) =
	[to_mfr_constraint(constraint, graph)]

# Specific implementations
to_mfr_constraint(constraint::PackRegionConstraint, graph::Graph) = 
	parse_pack_region_constraint(constraint)
to_mfr_constraint(constraint::CapRegionDistricts, graph::Graph) =
	parse_cap_region_constraint(constraint, graph)
# BRC uses the new list-output translator
to_mfr_constraints(constraint::BudgetedRegionConstraint, graph::Graph) =
	parse_budgeted_region_constraint(constraint)
# ... etc

"""
    parse_pack_region_constraint(constraint)

Convert a [`PackRegionConstraint`](@ref) to an MFR `PackNodeConstraint`, mapping each
region's required packed-district count onto its (one-tuple) region node key.
"""
function parse_pack_region_constraint(constraint::PackRegionConstraint)
	node_to_packed_dists = Dict{Tuple{Vararg{String}}, Int}()
	for (node, packed_dists) in constraint.region_to_packed_dists
		node_to_packed_dists[(node,)] = packed_dists
	end
	return PackNodeConstraint(node_to_packed_dists, constraint.ideal_pop)
end

"""
    parse_cap_region_constraint(constraint, graph)

Convert a [`CapRegionDistricts`](@ref) to an MFR `AllowedExcessDistsInCoarseNodes`.
Each region's district cap is reduced by its minimal proportional district count to
get the allowed excess; all regions must share a single excess value (asserted),
which becomes the MFR constraint's `excess_splitting`.
"""
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

"""
    parse_budgeted_region_constraint(constraint)

Convert a [`BudgetedRegionConstraint`](@ref) into the pair of MFR constraints it
implies: a `MaxTotalMissingPackedDistsInCoarseNodes` from its pack budget and a
`MaxTotalExcessDistsInCoarseNodes` from its cap budget.
"""
function parse_budgeted_region_constraint(
	constraint::BudgetedRegionConstraint
)
	return [
		MaxTotalMissingPackedDistsInCoarseNodes(
			constraint.pack_budget,
			constraint.ideal_pop,
		),
		MaxTotalExcessDistsInCoarseNodes(
			constraint.cap_budget,
			constraint.ideal_pop,
		),
	]
end
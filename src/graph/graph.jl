## move these functions to MetropolizeForestRecom.jl at some point

""""""
function multi_level_graph(base_graph::BaseGraph, levels::Vector{String})
    """
    Create a MultiLevelGraph with hierarchically ordered levels.

    Given a set of level names that are keys in `base_graph.node_attributes`,
    determine the strict hierarchical ordering (coarsest to finest) and return a
    MultiLevelGraph.

    # Arguments
    - `base_graph::BaseGraph`: The base graph with node attributes
    - `levels::Vector{String}`: Names of hierarchical levels, not necessarily
      already ordered

    # Returns
    - `MultiLevelGraph` with levels ordered from coarsest to finest

    # Notes
    - The containment relation is transitive: in a hierarchy A -> B -> C, level C
      determines both B and A.
    - We therefore first find all containment relations, then remove transitive
      ancestors and keep only immediate parents.
    - This preserves strictness while allowing valid nested geographic hierarchies
      with globally unique fine-level labels.

    # Errors
    - If any level name is not found in `node_attributes`
    - If a level has multiple immediate parents after removing transitive ancestors
    - If the hierarchy does not have exactly one root
    - If the hierarchy is disconnected

    """

    # Validate all levels exist in node_attributes.
    for level in levels
        if !all(haskey(node_attrs, level)
                for node_attrs in values(base_graph.node_attributes))
            error("Level '$level' not found in all node attributes")
        end
    end

    # Single level is trivial.
    if length(levels) == 1
        return MultiLevelGraph(base_graph, levels)
    end

    n = length(levels)

    # ancestor[parent, child] is true when levels[parent] is a parent
    # or transitive ancestor of levels[child].
    ancestor = falses(n, n)

    for child in 1:n
        for candidate_parent in 1:n
            child == candidate_parent && continue

            if is_parent(base_graph, levels[candidate_parent], levels[child])
                ancestor[candidate_parent, child] = true
            end
        end
    end

    # parent[child] = immediate parent index of levels[child].
    # A candidate parent is immediate only if there is no intermediate level
    # between it and the child.
    parent = fill(-1, n)

    for child in 1:n
        candidate_parents = [
            candidate_parent
            for candidate_parent in 1:n
            if ancestor[candidate_parent, child]
        ]

        immediate_parents = Int[]

        for candidate_parent in candidate_parents
            has_intermediate = false

            for intermediate in candidate_parents
                intermediate == candidate_parent && continue

                if ancestor[candidate_parent, intermediate] &&
                   ancestor[intermediate, child]
                    has_intermediate = true
                    break
                end
            end

            if !has_intermediate
                push!(immediate_parents, candidate_parent)
            end
        end

        if length(immediate_parents) == 1
            parent[child] = immediate_parents[1]
        elseif length(immediate_parents) > 1
            error(
                "Level $(levels[child]) has multiple immediate parents: " *
                join([levels[i] for i in immediate_parents], ", ") *
                ". Hierarchy must be strict."
            )
        end
    end

    # Find roots: levels with no immediate parent.
    roots = findall(x -> x == -1, parent)

    if length(roots) != 1
        error(
            "Hierarchy must have exactly one root level. " *
            "Found $(length(roots)) levels with no parent."
        )
    end

    # Topological sort from the unique root.
    ordered_indices = Int[]
    visited = falses(n)

    function dfs_order(idx::Int)
        if visited[idx]
            return
        end

        visited[idx] = true
        push!(ordered_indices, idx)

        for possible_child in 1:n
            if parent[possible_child] == idx
                dfs_order(possible_child)
            end
        end
    end

    dfs_order(roots[1])

    # Validate that all levels were reached.
    if length(ordered_indices) != n
        error("Hierarchy is not connected. Some levels are isolated or form cycles.")
    end

    ordered_levels = levels[ordered_indices]

    return MultiLevelGraph(base_graph, ordered_levels)
end

""""""
function is_parent(base_graph::BaseGraph, potential_parent::String, potential_child::String)::Bool
    """
    Check if potential_parent level is a parent of potential_child level.
    
    A level A is parent of level B if each distinct value of B maps to exactly
    one value of A (B is finer than A).
    """
    
        child_to_parent = Dict()
    
    for node_attrs in values(base_graph.node_attributes)
        parent_val = node_attrs[potential_parent]
        child_val = node_attrs[potential_child]
        
            if haskey(child_to_parent, child_val)
            # Check consistency
                if child_to_parent[child_val] != parent_val
                return false  # One parent value maps to multiple child values
            end
        else
                child_to_parent[child_val] = parent_val
        end
    end
    
    return true 
end

function modify_edge_weights!(
    base_graph::BaseGraph,
    edge_weight_func::Function
)
    for e in edges(base_graph.simple_graph)
        new_weight = edge_weight_func(base_graph, src(e), dst(e))
        base_graph.simple_graph.weights[src(e), dst(e)] = new_weight
        base_graph.simple_graph.weights[dst(e), src(e)] = new_weight
        key = Set([src(e), dst(e)])
        @assert haskey(base_graph.edge_attributes, key)
        edge_weights = base_graph.edge_weights
        base_graph.edge_attributes[key][edge_weights] = new_weight
    end
end

function modify_edge_weights!( 
    graph::MultiLevelGraph,
    edge_weight_func::Function
)
    base_graph = graph.graphs_by_level[end]
    modify_edge_weights!(base_graph, edge_weight_func)
    g = MultiLevelGraph(base_graph, graph.levels)
    for level in 1:graph.levels
        graph.graphs_by_level[level] = g.graphs_by_level[level]
        for ii in 1:length(graph.coarse_to_fine_graphs[level])
            new_graph = g.coarse_to_fine_graphs[level][ii]
            graph.coarse_to_fine_graphs[level][ii] = new_graph
        end
    end

    # Replace dictionary contents in place to avoid altering immutable struct.
    empty!(graph.mixed_nbr_weights)
    for (k, v) in g.mixed_nbr_weights
        graph.mixed_nbr_weights[k] = v
    end
end
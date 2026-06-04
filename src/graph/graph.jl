## move these functions to MetropolizeForestRecom.jl at some point

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
mutable struct LinkCutPartition <: AbstractPartition
    num_dists::Int64
    cross_district_edges::Dict{Tuple{Int64,Int64}, Set{SimpleWeightedEdge}}
    district_roots::Vector{Int64}
    roots_to_district::Dict{Int64, Int64}
    energy_data::Dict{Union{DataType, Tuple{DataType, Tuple}}, 
                      AbstractEnergyData}
    node_to_dist::Vector{Int64}
    node_to_dist_update::Vector{Int64}
    lct::LinkCutTree
    node_col::String
    graph::BaseGraph
    identifier::Int64
    # update_identifier::Int64
end

""""""
function LinkCutPartition(
    partition::MultiLevelPartition,
    rng::AbstractRNG=PCG.PCGStateOneseq(UInt64)
)::LinkCutPartition
    edge_type = edgetype(partition.subgraphs[1].graphs_by_level[1][()])
    edges = Vector{edge_type}(undef, 0)

    base_graph = partition.graph.graphs_by_level[end]
    node_to_dist = Vector{Int64}(undef, base_graph.num_nodes)
    node_to_dist_update = Vector{Int64}(undef, base_graph.num_nodes)
    log_tree_counts = Vector{Int64}(undef, partition.num_dists)

    for di = 1:partition.num_dists
        dg = partition.subgraphs[di].graphs_by_level[1][()]
        vmap = partition.subgraphs[di].vmaps[1][()]
        tree_edges = wilson_rst(dg, rng)
        tree_edges = [edge_type(vmap[src(e)],vmap[dst(e)], 
                                get_weight(dg, src(e), dst(e))) 
                      for e in tree_edges]
        edges = [edges; tree_edges]
    end

    # PopAug tree: carries per-node population so subtree populations are
    # maintained incrementally (see get_collapsed_cycle_weights / subtree_pop).
    pop_col = base_graph.pop_col
    pops = Float64[Float64(base_graph.node_attributes[ni][pop_col])
                   for ni in 1:base_graph.num_nodes]
    lct = pop_link_cut_tree(base_graph.simple_graph, edges, pops)
    district_roots, roots_to_district = get_district_roots(lct)
    @assert length(district_roots) == partition.num_dists

    energy_data = Dict{Union{DataType, Tuple{DataType, Tuple}}, 
                       AbstractEnergyData}()
    
    identifier = rand(rng, typemin(Int64):0)
    lcp = LinkCutPartition(partition.num_dists, 
                           Dict{Tuple{Int64,Int64}, Set{SimpleWeightedEdge}}(),
                           district_roots, roots_to_district, energy_data,
                           node_to_dist, node_to_dist_update, lct,
                           partition.graph.levels[1], base_graph,
                           identifier)#, identifier)
    assign_district_map!(lcp)
    find_cross_district_edges!(lcp)
    return lcp
end

""""""
function LinkCutPartition(
    graph::MultiLevelGraph, 
    constraints::Constraints,
    num_dists::U;
    rng::AbstractRNG=PCG.PCGStateOneseq(UInt64),
    verbose::Bool=false
) where U <: Int
    mfr_constraints, levels = interpret_constraints(constraints, graph)
    ml_graph = multi_level_graph(graph.graphs_by_level[end], levels)
    partition = MultiLevelPartition(ml_graph, mfr_constraints, num_dists; 
                                    rng=rng);
    node_to_dist = flatten_assignment(partition)
    partition = MultiLevelPartition(graph, node_to_dist)

    if verbose
        @show collect(keys(partition.district_to_nodes[1]))[1:min(10,end)]
    end
    lct_partition = LinkCutPartition(partition, rng)
    @assert satisfies_constraints(lct_partition, constraints; 
                                  check_population=true)
    return lct_partition;
end

""""""
function get_district_roots(lct::LinkCutTree)
    district_roots = Vector{Int}(undef, 0)
    roots_to_district = Dict{Int, Int}()
    for n in lct.nodes
        r = find_root!(n).vertex
        if r ∉ district_roots
            push!(district_roots, r)
            roots_to_district[r] = length(district_roots)
        end
    end 
    return district_roots, roots_to_district
end

""""""
function find_cross_district_edges!(
    lcp::LinkCutPartition,
    districts::Vector{Int} = collect(1:lcp.num_dists),
    cross_district_edges::Dict{Tuple{Int,Int}, Set{SimpleWeightedEdge}} 
    = lcp.cross_district_edges;
    update = false
)
    if update
        node_to_dist = lcp.node_to_dist_update
    else
        node_to_dist = lcp.node_to_dist
    end
    simple_graph = lcp.graph.simple_graph
    # The weighted adjacency is a SparseMatrixCSC, but `BaseGraph.simple_graph`
    # is stored with the abstract `SimpleWeightedGraph` type, so iterating its
    # CSC fields inline would be type-unstable. Pass the (concretely-typed at
    # runtime) weight matrix into a worker through a function barrier so the BFS
    # specializes and we can read each neighbor's weight straight from the column
    # instead of doing a per-edge binary-search `get_weight`.
    return _find_cross_district_edges!(lcp, districts, cross_district_edges,
                                       node_to_dist, weights(simple_graph),
                                       nv(simple_graph))
end

function _find_cross_district_edges!(
    lcp::LinkCutPartition,
    districts::Vector{Int},
    cross_district_edges::Dict{Tuple{Int,Int}, Set{SimpleWeightedEdge}},
    node_to_dist::Vector{Int},
    wmat,                       # SparseMatrixCSC; untyped so no SparseArrays import
    num_nodes::Int,
)
    # Column `v` of `wmat` stores each neighbor `n = rowval[k]` together with its
    # weight `nzval[k] == get_weight(graph, v, n)` (symmetric, undirected graph).
    colptr = wmat.colptr
    rowval = wmat.rowval
    nzval = wmat.nzval
    visited_nodes = falses(num_nodes)
    for di in districts
        r = lcp.district_roots[di]
        queue = [r]
        while length(queue) > 0
            v = pop!(queue)
            visited_nodes[v] = true
            for k in colptr[v]:(colptr[v + 1] - 1)
                n = rowval[k]
                if visited_nodes[n] continue end
                w = nzval[k]
                if w == 0 continue end
                dj = node_to_dist[n]
                if di == dj
                    push!(queue, n)
                else
                    dij = (min(di,dj), max(di, dj))
                    edgeset = get!(() -> Set{SimpleWeightedEdge}(),
                                   cross_district_edges, dij)
                    push!(edgeset, SimpleWeightedEdge(v, n, w))
                end
            end
        end
    end
    return cross_district_edges
end

function assign_district_map!(
    partition::LinkCutPartition, 
    districts::Vector{Int} = collect(1:partition.num_dists);
    update = false
) 
    if update
        node_to_dist = partition.node_to_dist_update
    else 
        node_to_dist = partition.node_to_dist
    end

    for di in districts
        ri = partition.district_roots[di]
        node_r = partition.lct.nodes[ri]
        expose!(node_r)
        queue = [node_r]
        while length(queue) > 0
            node = pop!(queue)
            node_to_dist[node.vertex] = di
            for ii = 1:2
                if node.children[ii] != nothing
                    push!(queue, node.children[ii])
                end
            end
            c = first_path_child(node)
            while c !== nothing
                push!(queue, c)
                c = next_path_sibling(c)
            end
        end
    end
end

function sum_cc(
    node::Node, 
    partition::LinkCutPartition, 
    field::String, 
    start=true
) 
    if start
        expose!(node)
    end
    sum = partition.graph.node_attributes[node.vertex][field]
    for ii = 1:2
        if node.children[ii] != nothing
            sum += sum_cc(node.children[ii], partition, field, false)
        end
    end
    c = first_path_child(node)
    while c !== nothing
        sum += sum_cc(c, partition, field, false)
        c = next_path_sibling(c)
    end
    return sum
end


function topological_sort!(
    cut_remainder::Dict{Int, Float64},
    node::Union{Node, Nothing},
    source::Node,
    partition::LinkCutPartition,
    field::Union{Nothing,String},
    reversed::Bool=false,
    mass::Float64=0.0,
)
    if node === nothing
        return 0.0
    end

    remainder = 0.0
    reversed ⊻= node.reversed
    if !reversed; lc,rc = 1,2; else lc,rc=2,1 end
    remainder += topological_sort!(cut_remainder, node.children[rc], node, 
                                   partition, field, reversed, mass)
    c = first_path_child(node)
    while c !== nothing
        remainder += topological_sort!(cut_remainder, c, node, partition, field)
        c = next_path_sibling(c)
    end

    index = node.vertex
    # typed local: the `node_attributes` read is `Any`, so assert Float64 to keep
    # inference concrete and avoid boxing the result and everything downstream.
    node_val::Float64 = 1.0 # if nothing, just count nodes
    if field !== nothing
        node_val = partition.graph.node_attributes[index][field]
    end
    cut_remainder[index] = remainder + node_val + mass

    if source != node.children[lc]
        remainder += topological_sort!(cut_remainder, node.children[lc], node,
                                       partition, field, reversed,
                                       cut_remainder[index])
    end
    return remainder + node_val
end

function topological_sort(root::Node, partition::LinkCutPartition; 
                          field::Union{Nothing,String}=partition.graph.pop_col)
    cut_remainder = Dict{Int,Float64}()
    evert!(root)
    if !root.reversed; lc,rc = 1,2; else lc,rc=2,1 end

    # # the following should all be handled by the evert!; this is to confirm
    # @assert root.children[lc] === nothing
    # @assert root.parent === nothing
    # @assert root.pathParent === nothing

    total = topological_sort!(cut_remainder, root.children[rc], root, 
                              partition, field, root.reversed)

    c = first_path_child(root)
    while c !== nothing
        total += topological_sort!(cut_remainder, c, root, partition, field)
        c = next_path_sibling(c)
    end
    root_pop::Float64 = 1.0 # if field === nothing, just count number of nodes
    if field !== nothing
        root_pop = partition.graph.node_attributes[root.vertex][field]
    end
    cut_remainder[root.vertex] = root_pop + total

    return cut_remainder
end

"
Gets the diameter of the trees held in a LinkCutPartition
"
function get_diameters(partition::LinkCutPartition)
    return get_diameter.(partition.lct.nodes[partition.district_roots])
end

"
gets the neighbor list representations of the trees held in a LinkCutPartition
"

function get_neighbor_lists(partition::LinkCutPartition)
    roots = partition.lct.nodes[partition.district_roots]
    edgeLists = get_connected_edge_list.(roots)
    graphs = get_neighbor_lists(edgeLists)
    return graphs
end

"
gets the degree distribution of the link/cut trees held in a LinkCutPartition
"
function get_degree_distributions(partition::LinkCutPartition)
    edgeLists=LiftedTreeWalk.get_connected_edge_list.(
                                  partition.lct.nodes[partition.district_roots])
    distributionsList=get_degree_distribution.(edgeLists)
    return distributionsList
end 

"
calculates the average degree of the trees in a LinkCutPartition
"
function get_average_degrees(partition::LinkCutPartition)
    edgeLists=LiftedTreeWalk.get_connected_edge_list.(
                                  partition.lct.nodes[partition.district_roots])
    averageDegreeList=get_average_degree.(edgeLists)
    return averageDegreeList
end 


"
calculates the center of the trees in a LinkCutPartition and then the L^p norm 
of the distances of the vertices from that center vertex
"
function get_center_moments(partition::LinkCutPartition;p=1)
    edgeList=LiftedTreeWalk.get_connected_edge_list.(
                                  partition.lct.nodes[partition.district_roots])

    center_moments=get_center_moment.(edgeList,p=p)

    return center_moments

end

"
calculates the center of the trees in a LinkCutPartition and then the L^p norm 
of the distances of the leaves from that center vertex
"
function get_center_leaves_moments(partition::LinkCutPartition;p=1)
    edgeList=LiftedTreeWalk.get_connected_edge_list.(
                                  partition.lct.nodes[partition.district_roots])

    center_moments=get_center_leaves_moment.(edgeList,p=p)

    return center_moments

end















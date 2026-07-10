# Edge-list / neighbor-list tree metrics.
#
# These operate on plain edge lists and neighbor dictionaries (not on the
# link-cut tree itself), so they live in CycleWalk rather than in the
# LinkCutTreesAugmented package. The link-cut-tree data structure and its
# traversals now come from LinkCutTreesAugmented (see CycleWalk.jl `using`).

"""
    get_neighbor_list(edgeList)

Build an adjacency (neighbor) list from a vector of undirected `Edge`s, returned as
a `Dict` mapping each vertex to a vector of its neighbors. Both endpoints of every
edge are recorded, so the result represents the edge list as an undirected graph.
"""
function get_neighbor_list(edgeList::Vector{Edge})
    g=Dict()
    for e in edgeList
        if !(dst(e) in keys(g))
            g[dst(e)]=Vector{Int64}()
        end
        append!(g[dst(e)],src(e))
        if !(src(e) in keys(g))
            g[src(e)]=Vector{Int64}()
        end
        append!(g[src(e)],dst(e))
    end
    return g
end

"""
    get_neighbor_lists(edgeListVector)

Broadcast [`get_neighbor_list`](@ref) over a vector of edge lists (e.g. one per
district), returning the vector of corresponding neighbor-list `Dict`s.
"""
function get_neighbor_lists(edgeListVector::Vector{Vector{E}}) where E<:Edge
    graphList=get_neighbor_list.(edgeListVector)
    return graphList
end

"gets the degree distribution from an edge list"
function get_degree_distribution(edgeList::Vector{Edge})
    v=Dict()
    for e in edgeList
        if !(dst(e) in keys(v))
            v[dst(e)]=1
        else
            v[dst(e)]+=1
        end
        if !(src(e) in keys(v))
            v[src(e)]=1
        else
            v[src(e)]+=1
        end
    end

    distribution=SortedDict()
    for val in values(v)
        if !(val in keys(distribution))
            distribution[val]=1
        else
            distribution[val]+=1
        end
    end
    return distribution
end



"gets the degree distribution from an vector of edge lists"
function get_degree_distributions(edgeListVector::Vector{Vector{E}}) where E<:Edge
    distributionsList=get_degree_distribution.(edgeListVector)
    return distributionsList
end

"gets the average degree  from  edge list"
function get_average_degree(edgeList::Vector{Edge})
    v=Dict()
    for e in edgeList
        if !(dst(e) in keys(v))
            v[dst(e)]=1
        else
            v[dst(e)]+=1
        end
        if !(src(e) in keys(v))
            v[src(e)]=1
        else
            v[src(e)]+=1
        end
    end

    return sum(values(v))/length(v)
end

"
gets the neighbor list and degree distribution from a edge list vector
"
function get_neighbor_list_and_degrees(edgeList::Vector{E}) where E<:Edge
    degree=Dict{Int64,Int64}()
    edges=Dict{Int64,Vector{Int64}}()
    for e in edgeList

        if !(dst(e) in keys(degree))
            degree[dst(e)]=1
            edges[dst(e)]=[src(e)]
        else
            degree[dst(e)]+=1
            push!(edges[dst(e)],src(e))
        end
        if !(src(e) in keys(degree))
            degree[src(e)]=1
            edges[src(e)]=[dst(e)]
        else
            degree[src(e)]+=1
            push!(edges[src(e)],dst(e))
        end
    end
    return degree,edges
end

"
gets the center of a tree and the leaves of the tree.
if  distances=true then the distence from all of the verticies
    to the center are also returned
"

function get_tree_centers_and_leaves(edgeList::Vector{E};
    distances=false) where E<:Edge
    degree, neighbors  =get_neighbor_list_and_degrees(edgeList)
    n=length(degree)

    # Initialize the leaves
    leaves=Vector{Int64}()
    for v in keys(degree)
        if degree[v] == 1
            push!(leaves, v)
            degree[v] -= 1  # Mark as visited
        end
    end

    saveLeaves=leaves

    # Iteratively remove leaves
    while n > 2
        new_leaves = Vector{Int64}()
        for leaf in leaves
            n -= 1  # Remove leaf
            for neighbor in neighbors[leaf]
                degree[neighbor] -= 1
                if degree[neighbor] == 1
                    push!(new_leaves, neighbor)
                end
            end
        end
        leaves = new_leaves
    end



    # Calculate distances to center of each leaf if requested
    if distances
        distances=[]
        for leaf in leaves
            ds=get_distances_BFS(neighbors,leaf)
            push!(distances,ds)
        end
        return leaves,saveLeaves,distances
    else
        return leaves,saveLeaves
    end
end


"""
    get_center_moment(edgeList; p=1)

Compute the `Lᵖ` moment of the distances from the tree's center to *all* of its
vertices. The tree's center (one or two vertices) is found by iteratively peeling
leaves; for each vertex the distances from every center are averaged, raised to the
`p`-th power and averaged over vertices, and the `p`-th root is returned. Larger
values indicate a more elongated/less compact tree.
"""
function get_center_moment(edgeList::Vector{E};p=1) where E<:Edge

    centers,leaves,distances=get_tree_centers_and_leaves(edgeList,distances=true)

    total_distance=0.0
    num_centers=length(centers)

    for v in keys(distances[1])
        local_sum=0.0
        for d in distances
            local_sum+=d[v]
        end
        total_distance+=(local_sum/num_centers)^p
    end

    return (total_distance/length(distances[1]))^(1.0/p)
end

"""
    get_center_leaves_moment(edgeList; p=1)

Like [`get_center_moment`](@ref), but takes the `Lᵖ` moment of the center-to-vertex
distances over only the tree's *leaves* (degree-one vertices) rather than all
vertices.
"""
function get_center_leaves_moment(edgeList::Vector{E};p=1) where E<:Edge

    centers,leaves,distances=get_tree_centers_and_leaves(edgeList,distances=true)

    total_distance=0.0
    num_centers=length(centers)

    for v in leaves
        local_sum=0.0
        for d in distances
            local_sum+=d[v]
        end
        total_distance+=(local_sum/num_centers)^p
    end
    return (total_distance/length(leaves))^(1.0/p)
end

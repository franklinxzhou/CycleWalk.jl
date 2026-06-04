"""
    link_cut_tree(g)

 Returns a link_cut_tree data structure from a graph that is a rooted, 
 directed tree or forest of trees https://dl.acm.org/doi/10.1145/3828.3835

 Directed trees are sometimes called 
 [polytrees](https://en.wikipedia.org/wiki/Polytree)). 

"""
function link_cut_tree(g::AG) where {U,AG<:AbstractGraph{U}}
    tree = LinkCutTree{U}(nv(g))

    for n in vertices(g)
        for c in neighbors(g,n)
            link!(tree.nodes[c],tree.nodes[n])
        end
    end

    return tree
end

function link_cut_tree(g, tree_edges::Vector)
    tree = LinkCutTree{Int}(nv(g))

    for e in tree_edges
        evert!(tree.nodes[src(e)])
        link!(tree.nodes[src(e)],tree.nodes[dst(e)])
    end

    return tree
end

#Link Cut Functions:
struct LinkCutTree{T<:Integer}
    #nodes should be ordered- the first node is vertex 1, etc.
    nodes::AbstractArray{Union{Node, Nothing}}


    function LinkCutTree{T}(s::Integer) where {T<:Integer} 
        f = new(Vector{Union{Node, Nothing}}(undef,s))
        for n in 1:length(f.nodes)
            f.nodes[n] = Node(convert(T,n))
        end
        return f
    end

    function LinkCutTree{T}(
        n::AbstractArray{Union{Node, Nothing}}
    ) where {T<:Integer}
        t = new(n)
        return t
    end
end
#linkCutForest{T}() where {T<:Integer} = linkCutFoest{T}(Vector{Union{Node, Nothing}}[])
# function Base.getindex(lct::LinkCutTree, ii::Int) where {T<:Integer} 
#     return lct.nodes[ii]
# end

function Base.getindex(lct::LinkCutTree, ind::T) where T<:Int
    # Define special lookup logic
    return lct.nodes[ind]
end

"""
Returns a vector of integers, each entry i indicating the index of the parent of the node at index i.
"""
function parents(f::LinkCutTree{T}) where {T<:Integer}
    nodes = copy(f.nodes)
    p = Vector{T}(undef,length(f.nodes))
    visited = Vector{Bool}([false for _ = 1:length(nodes)])

    pos = 1
    while pos <= length(nodes)
        while pos <= length(nodes) && visited[pos] 
            pos += 1
        end
        if pos > length(nodes)
            break
        end
        r = findSplayRoot(nodes[pos])
        s = traverseSubtree(r)
        if r.pathParent isa Node
            p[s[1].vertex] = r.pathParent.vertex
        else
            p[s[1].vertex] = s[1].vertex
        end
        for i in 2:lastindex(s)
            p[s[i].vertex] = s[i-1].vertex
        end
        for n in s
            visited[n.vertex] = true
        end
    end

    return p

end

"Returns a vector of the current subtree that n is in, in order of depth on the represented tree."
function findPath(n::Node)
    return traverseSubtree(findSplayRoot(n))
end

"returns a vector of the integer labels for the current subtree that the node indexed by i is in,
 in the tree t, in order of depth on the represented tree."
function findPath(i::Integer, t::LinkCutTree)
    A = traverseSubtree(findSplayRoot(t.nodes[i]))
    B = Vector{Integer}(undef,length(A))
    for i in eachindex(A)
        B[i] = A[i].vertex
    end
    return B
end

"Replaces the right subtree of n with r, or with nothing if r is unspecified.
the old right subtree of n is moved to a separate auxillary tree and tracked with a path-parent pointer."
function replaceRightSubtree!(n::Node, r::Union{Node, Nothing}=nothing)
    c = n.children[2]
    if c isa Node
        c.pathParent = n
        c.parent = nothing
        push!(n.pathChildren, c)
    end

    setRight!(n,r)
    if r isa Node
        r.pathParent = nothing
        delete!(n.pathChildren, r)
    end

end


"Moves n to the tree at the root of the link-cut tree using splay tree operations.
Preserves the represented tree, and n will be the deepest node on the preferred path."
function expose!(n::Node)

    splay!(n)
    replaceRightSubtree!(n)

    while n.pathParent isa Node
        p = n.pathParent
        splay!(p)
        replaceRightSubtree!(p,n)
        splay!(n)
    end
end

"Links two represented trees, where u is the root of one represented tree and becomes a child of v."
function link!(u::Node, v::Node)

    expose!(u)
    if u.children[1] isa Node
        throw(ArgumentError("u must be the root of its represented tree to link."))
    end

    expose!(v)
    if u.parent isa Node || u.pathParent isa Node
        throw(ArgumentError("Can't link two nodes in the same represented tree"))
    end
    u.pathParent = v
    push!(v.pathChildren, u)
end

"Cuts the node u away from its parent in the represented tree.
u cannot be the root of the represented tree."
function cut!(u::Node)
    expose!(u)

    if !(u.children[1] isa Node)
        throw(ArgumentError("can't cut the root of the represented tree."))
    end

    v = u.children[1]

    v.parent = nothing
    setLeft!(u, nothing)

end

"Changes the root of the represented tree to u."
function evert!(u::Node)
    expose!(u)

    u.reversed = true
end

const (set_root!)=(evert!)

"Changes the root of the represented tree to u."
function find_root!(u::Node)
    expose!(u)
    while u.children[1] != nothing
        u = u.children[1]
    end
    return u
end

function nv_cc(node::Node, start=true) 
    if start
        expose!(node)
    end
    count = 1
    for ii = 1:2
        if node.children[ii] != nothing
            count += nv_cc(node.children[ii], false)
        end
    end
    for n in node.pathChildren
        count += nv_cc(n, false)
    end
    return count
end

function cc(node::Node, start=true, vec::Vector{Int}=Vector{Int}(undef,0)) 
    if start
        expose!(node)
    end
    push!(vec, node.vertex)
    
    for ii = 1:2
        if node.children[ii] != nothing
            cc(node.children[ii], false, vec)
        end
    end
    for n in node.pathChildren
        cc(n, false, vec)
    end
    return vec
end

function get_connected_edge_list!(
    edges::Vector{Edge},
    node::Union{Node, Nothing},
    linking::Node, 
    reversed::Bool=false
)
    if node === nothing
        return linking
    end

    reversed ⊻= node.reversed
    if !reversed; lc,rc = 1,2; else lc,rc=2,1 end

    linking = get_connected_edge_list!(edges, node.children[lc], linking, 
                                       reversed)
    push!(edges, Edge(node.vertex, linking.vertex))
    linking = node

    linking = get_connected_edge_list!(edges, node.children[rc], linking, 
                                       reversed)

    for n in node.pathChildren
        get_connected_edge_list!(edges, n, node)
    end

    return linking
end

function get_connected_edge_list(root::Node)
    edges = Vector{Edge}(undef, 0)
    evert!(root)
    if !root.reversed; lc,rc = 1,2; else lc,rc=2,1 end

    get_connected_edge_list!(edges, root.children[rc], root, root.reversed)

    for n in root.pathChildren
        get_connected_edge_list!(edges, n, root)
    end
    return edges
end

"This is a function used in the recursive calls of  
get_farthest_node which is a version of a BFS on link/cut trees to 
find the farthest node from a give node "
function get_farthest_node(
    node::Union{Node, Nothing},
    linking::Node, 
    deepest_node::Node=linking,
    deepest_dist::Int64=0,
    cur_dist::Int64=0;
    reversed::Bool=false
)
    if node === nothing
        return linking, cur_dist, deepest_node, deepest_dist
    end

    reversed ⊻= node.reversed
    if !reversed; lc,rc = 1,2; else lc,rc=2,1 end

    linking, cur_dist, dn, dd = get_farthest_node(node.children[lc], linking, 
                                                   deepest_node, deepest_dist, 
                                                   cur_dist, reversed=reversed)
    cur_dist += 1
    linking = node
    if cur_dist > deepest_dist
        deepest_node = node
        deepest_dist = cur_dist
    end
    if dd > deepest_dist
        # @show "here 1", dd, dn.vertex, deepest_dist, deepest_node.vertex
        deepest_node = dn
        deepest_dist = dd
    end

    # @show "pc", node.vertex, linking.vertex, cur_dist
    for n in node.pathChildren
        _, _, dn, dd = get_farthest_node(n, node, deepest_node, deepest_dist, 
                                         cur_dist)
        if dd > deepest_dist
            deepest_node = dn
            deepest_dist = dd
        end
    end

    linking, cur_dist, dn, dd = get_farthest_node(node.children[rc], linking, 
                                                   deepest_node, deepest_dist, 
                                                   cur_dist, reversed=reversed)
    if dd > deepest_dist
        deepest_node = dn
        deepest_dist = dd
    end

    return linking, cur_dist, deepest_node, deepest_dist
end

"A version of a BFS on link/cut trees to 
find the farthest node from a give node "
function get_farthest_node(root::Node)
    evert!(root)
    if !root.reversed; lc,rc = 1,2; else lc,rc=2,1 end

    _, _, node, dist = get_farthest_node(root.children[rc], root, 
                                         reversed=root.reversed)

    for n in root.pathChildren
        _, _, fn, d = get_farthest_node(n, root)
        if d > dist
            dist = d
            node = fn
        end
    end
    return node, dist
end

function get_diameter(root::Node)
    farthest_node, _ = get_farthest_node(root)
    _, diameter = get_farthest_node(farthest_node)
    evert!(root)
    return diameter
end

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




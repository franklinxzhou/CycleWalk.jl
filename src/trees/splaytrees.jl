"""
    AbstractNode

An abstract type with two subtypes: Node and DummyNode. DummyNode will be a singleton type,
and represents a node that isn't in the represented tree (like the children of a leaf node).
Node will represent a node of a splay tree. 
as the LCT will be used to represent a graph, each node must remember what vertex it represents.
as such, T is whatever type is used to keep track of the vertices.
"""
# abstract type AbstractNode{T} end

mutable struct Node{T}

    vertex::T
    parent::Union{Node{T}, Nothing}
    pathParent::Union{Node{T}, Nothing}
    children::Vector{Union{Node{T}, Nothing}}
    reversed::Bool
    pathChildren::Set{Node{T}}

    function Node{T}(
        vertex, parent::Union{Node, Nothing},
        leftchild::Union{Node, Nothing},
        rightchild::Union{Node, Nothing},
        pathParent::Union{Node, Nothing},
    ) where {T}
        n = new(vertex, parent, pathParent)
        n.reversed = false
        n.children = Vector{Union{Node{T}, Nothing}}(undef,2)
        setLeft!(n, leftchild)
        setRight!(n, rightchild)
        n.pathChildren = Set{Node{T}}()
        return n
    end

end
Node(vertex::T) where {T} = Node{T}(vertex, nothing, nothing, nothing, nothing) 


#Getters and Setters:
function setParent!(n::Union{Node, Nothing} , p::Union{Node, Nothing})
    if n == nothing
        return nothing
    end
    n.parent = p
end

function setChild!(n::Node, i::Int, c::Union{Node, Nothing})
    n.children[i] = c
    setParent!(c,n)
end

function setLeft!(n::Node, l::Union{Node, Nothing})
    setChild!(n,1,l)
end

function setRight!(n::Node, r::Union{Node, Nothing})
    setChild!(n,2,r)
end


#Finding information / utility functions:
function sameNode(n1::Union{Node, Nothing} ,n2::Union{Node, Nothing})
    if n1 isa Node && n2 isa Node 
        return n1.vertex == n2.vertex
    end
    return n1 == n2        
end

"Returns the index n has in its parent's vector of children. Requires a real parent."
function childIndex(n::Node)
    c = n.parent.children
    return sameNode(n, c[1]) ? 1 : (sameNode(n, c[2]) ? 2 : nothing)
end

function findSplayRoot(n::Node)
    r = n
    while r.parent isa Node
        r = r.parent
    end
    return r
end

"Finds the left- or right-most node in the splay tree of n."
function findExtreme(n::Node, largest::Bool)
    r = findSplayRoot(n)
    childIndex = 1
    largest && (childIndex+=1)==2

    while r.children[childIndex] isa Node
        r = r.children[childIndex]
    end

    return r
end


#don't export this, the other one is the wrapper that should be called.
function traverseSubtree!(A::Array, n::Node, order::Int, reverse::Bool)

    if order == 1
        append!(A,[n])
    end

    for i in 0:1
        if i == 1 && order == 2
            append!(A, [n])
        end

        c = n.children[(i⊻n.reversed⊻reverse)+1]
        if c isa Node
            traverseSubtree!(A,c,order,n.reversed⊻reverse)
        end

    end

    if order == 3
        append!(A,[n])
    end

end

"returns an array with the desired traversal of the subtree of n."
function traverseSubtree(n::Node, order::String="in-order")
    A = Vector{Node}(undef, 0)

    pre_order, in_order, post_order = false,false,false

    (pre_order=(order=="pre-order"))||(in_order=(order=="in-order"))||(post_order=(order=="post-order"))

    order = pre_order + in_order*2 + post_order*3

    traverseSubtree!(A,n,order,false)

    return A
end




#splay tree modification:
"Rotates n upwards in the splay tree while maintaining BST rules. Requires a real parent."
function rotateUp(n::Node)
    i = childIndex(n)
    p = n.parent
    g = p.parent

    setParent!(n,g)
    if g isa Node
        j = childIndex(p)
        setChild!(g,j,n)
    else
        n.pathParent = p.pathParent
        t = typeof(n.vertex)
        p.pathParent = nothing
        if n.pathParent != nothing
            delete!(n.pathParent.pathChildren, p)
            push!(n.pathParent.pathChildren, n)
        end
    end

    #move n's correct child into the place where n used to be, beneath p.
    setChild!(p, i, n.children[3-i])
    #set p to be n's correct child.
    setChild!(n,3-i,p)

end

"Alters the tree until n is the root. Does not disrupt the ordering."
function splay!(n::Node)
    pushReversed!(n)
    while n.parent isa Node
        p = n.parent
        
        #just zig; n is a child of the root.
        if p.parent == nothing
            rotateUp(n)

        # zig-zig: n<p<p.parent, or n>p>p.parent
        elseif childIndex(n) == childIndex(p)
            rotateUp(p)
            rotateUp(n)
        
        #zig-zag: p<n<p.parent, or p.parent<n<p
        else 
            rotateUp(n)
            rotateUp(n)
        end
    end
end

function pushReversed!(n::Node)
    if typeof(n.parent) <: Node
        pushReversed!(n.parent)
    end

    if n.reversed 
        tmp = n.children[1]
        n.children[1] = n.children[2]
        n.children[2] = tmp
        for c in n.children
            if c isa Node
             c.reversed = !c.reversed
            end
        end
        n.reversed = false
    end
end


# struct DummyNode{T} <: AbstractNode{T} end



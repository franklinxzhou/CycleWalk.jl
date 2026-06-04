
@testset "LinkCutTree" begin

    @testset "isolated nodes are their own roots" begin
        lct = CycleWalk.LinkCutTree{Int}(4)
        for i in 1:4
            @test CycleWalk.find_root!(lct.nodes[i]).vertex == i
        end
    end

    @testset "link! places nodes in one tree" begin
        # Star: node 1 is root, 2 and 3 are children of 1
        lct = CycleWalk.LinkCutTree{Int}(3)
        CycleWalk.link!(lct.nodes[2], lct.nodes[1])
        CycleWalk.link!(lct.nodes[3], lct.nodes[1])
        @test CycleWalk.find_root!(lct.nodes[1]).vertex == 1
        @test CycleWalk.find_root!(lct.nodes[2]).vertex == 1
        @test CycleWalk.find_root!(lct.nodes[3]).vertex == 1
    end

    @testset "chain shares a single root" begin
        # Chain: 1 is root, 2 is child of 1, 3 is child of 2
        lct = CycleWalk.LinkCutTree{Int}(3)
        CycleWalk.link!(lct.nodes[2], lct.nodes[1])
        CycleWalk.link!(lct.nodes[3], lct.nodes[2])
        @test CycleWalk.find_root!(lct.nodes[1]).vertex == 1
        @test CycleWalk.find_root!(lct.nodes[2]).vertex == 1
        @test CycleWalk.find_root!(lct.nodes[3]).vertex == 1
    end

    @testset "evert! changes the root" begin
        # Chain 1→2→3; evert to make 3 the new root
        lct = CycleWalk.LinkCutTree{Int}(3)
        CycleWalk.link!(lct.nodes[2], lct.nodes[1])
        CycleWalk.link!(lct.nodes[3], lct.nodes[2])
        @test CycleWalk.find_root!(lct.nodes[2]).vertex == 1
        CycleWalk.evert!(lct.nodes[3])
        @test CycleWalk.find_root!(lct.nodes[1]).vertex == 3
        @test CycleWalk.find_root!(lct.nodes[2]).vertex == 3
        @test CycleWalk.find_root!(lct.nodes[3]).vertex == 3
    end

    @testset "cut! splits a tree into two components" begin
        # Chain 1→2→3; cut node 2 from its parent
        lct = CycleWalk.LinkCutTree{Int}(3)
        CycleWalk.link!(lct.nodes[2], lct.nodes[1])
        CycleWalk.link!(lct.nodes[3], lct.nodes[2])
        CycleWalk.cut!(lct.nodes[2])
        # Node 1 is now its own tree; nodes 2 and 3 form a separate tree
        @test CycleWalk.find_root!(lct.nodes[1]).vertex == 1
        @test CycleWalk.find_root!(lct.nodes[2]).vertex == 2
        @test CycleWalk.find_root!(lct.nodes[3]).vertex == 2
    end

    @testset "two disjoint trees have distinct roots" begin
        lct = CycleWalk.LinkCutTree{Int}(6)
        # Tree A: root=1, children 2 and 3
        CycleWalk.link!(lct.nodes[2], lct.nodes[1])
        CycleWalk.link!(lct.nodes[3], lct.nodes[1])
        # Tree B: root=4, children 5 and 6
        CycleWalk.link!(lct.nodes[5], lct.nodes[4])
        CycleWalk.link!(lct.nodes[6], lct.nodes[4])
        root_A = CycleWalk.find_root!(lct.nodes[1]).vertex
        root_B = CycleWalk.find_root!(lct.nodes[4]).vertex
        @test root_A == CycleWalk.find_root!(lct.nodes[2]).vertex
        @test root_A == CycleWalk.find_root!(lct.nodes[3]).vertex
        @test root_B == CycleWalk.find_root!(lct.nodes[5]).vertex
        @test root_B == CycleWalk.find_root!(lct.nodes[6]).vertex
        @test root_A != root_B
    end

    @testset "parents() returns correct parent array for a chain" begin
        # Chain 1→2→3→4 where 1 is root
        lct = CycleWalk.LinkCutTree{Int}(4)
        CycleWalk.link!(lct.nodes[2], lct.nodes[1])
        CycleWalk.link!(lct.nodes[3], lct.nodes[2])
        CycleWalk.link!(lct.nodes[4], lct.nodes[3])
        p = CycleWalk.parents(lct)
        @test p[1] == 1  # root is its own parent
        @test p[2] == 1
        @test p[3] == 2
        @test p[4] == 3
    end

    @testset "cc() returns all vertices in the component" begin
        lct = CycleWalk.LinkCutTree{Int}(4)
        # Two trees: {1,2} and {3,4}
        CycleWalk.link!(lct.nodes[2], lct.nodes[1])
        CycleWalk.link!(lct.nodes[4], lct.nodes[3])
        @test sort(CycleWalk.cc(lct.nodes[1])) == [1, 2]
        @test sort(CycleWalk.cc(lct.nodes[3])) == [3, 4]
    end

    @testset "cutting the root throws ArgumentError" begin
        lct = CycleWalk.LinkCutTree{Int}(2)
        CycleWalk.link!(lct.nodes[2], lct.nodes[1])
        @test_throws ArgumentError CycleWalk.cut!(lct.nodes[1])
    end

    @testset "linking a non-root node throws ArgumentError" begin
        lct = CycleWalk.LinkCutTree{Int}(3)
        CycleWalk.link!(lct.nodes[2], lct.nodes[1])
        # node2 is a child of node1, so it is not a tree root
        @test_throws ArgumentError CycleWalk.link!(lct.nodes[2], lct.nodes[3])
    end

end

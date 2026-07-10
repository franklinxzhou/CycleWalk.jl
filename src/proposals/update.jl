"""
    Update{T <: Int}

A tentative cycle-walk proposal: the edits needed to turn the current partition into
the proposed one, so the move can be scored, accepted, or reverted without rebuilding
the partition.

Fields:
- `changed_districts`: the (one or two) district indices the move affects.
- `links`: edges to add (`[u, v]` vertex pairs).
- `cuts`: edges to remove.
- `new_cross_d_edg`: the recomputed cross-district edges for the changed districts.
- `swap_link11`: whether the two new district roots must be swapped to keep the
  district→root labeling consistent (see `find_proposal_prob_ratio!`).
- `identifier`: a flattened key of the changed districts and edited edges, used to
  detect whether cached energy data matches this update.
"""
struct Update{T <: Int}
    changed_districts::Tuple{Vararg{Int64}}
    links::Vector{Vector{T}}
    cuts::Vector{Vector{T}}
    new_cross_d_edg::Dict{Tuple{T,T}, Set{SimpleWeightedEdge}}
    swap_link11::Bool
    identifier::Vector{T}
end

"""
    Update(changed_districts, links, cuts, new_cross_d_edg, swap_link11)

Construct an [`Update`](@ref), deriving the `identifier` by concatenating the changed
district indices with the link and cut vertex pairs.
"""
function Update(
    changed_districts::Tuple{Vararg{T}},
    links::Vector{Vector{T}},
    cuts::Vector{Vector{T}},
    new_cross_d_edg::Dict{Tuple{T,T}, Set{SimpleWeightedEdge}},
    swap_link11::Bool
)::Update{T} where T <: Int 
    identifier = collect(changed_districts)
    for l in links
        append!(identifier, l)
    end
    for c in cuts
        append!(identifier, c)
    end
    Update{T}(changed_districts, links, cuts, new_cross_d_edg, swap_link11, 
              identifier)
end
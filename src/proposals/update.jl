struct Update{T <: Int}
    changed_districts::Tuple{Vararg{Int64}}
    links::Vector{Vector{T}}
    cuts::Vector{Vector{T}}
    new_cross_d_edg::Dict{Tuple{T,T}, Set{SimpleWeightedEdge}}
    swap_link11::Bool
    identifier::Vector{T}
end 

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
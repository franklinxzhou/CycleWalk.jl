import Base: isslotfilled

"""
    rand_set_element(r, s)

Return a uniformly random element of the `Set` `s` in `O(1)` expected time by
rejection-sampling filled slots of the underlying hash table, avoiding the
allocation of `collect(s)`. Throws if `s` is empty.
"""
function rand_set_element(r::AbstractRNG, s::Set)
    isempty(s) && throw(ArgumentError("set must be non-empty"))
    n = length(s.dict.slots)
    while true
        i = rand(r, 1:n)
        isslotfilled(s.dict, i) && return s.dict.keys[i]
    end
end

"""
    rand_set_element_and_ind(r, s)

Like [`rand_set_element`](@ref) but also returns the internal slot index of the
chosen element, as `(element, index)`. The index lets a follow-up draw exclude this
element (see [`rand_set_element_pair`](@ref)).
"""
function rand_set_element_and_ind(r::AbstractRNG, s::Set)
    isempty(s) && throw(ArgumentError("set must be non-empty"))
    n = length(s.dict.slots)
    while true
        i = rand(r, 1:n)
        isslotfilled(s.dict, i) && return s.dict.keys[i], i
    end
end

"""
    rand_set_element_pair(r, s)

Return an ordered pair `(b, a)` of two *distinct* uniformly random elements of the
`Set` `s`, again sampling filled hash-table slots directly. Throws if `s` has fewer
than two elements.
"""
function rand_set_element_pair(r::AbstractRNG, s::Set)
    length(s) < 2 && throw(ArgumentError("set must have two or more elements"))
    n = length(s.dict.slots)
    el, first = rand_set_element_and_ind(r, s)
    while true
        i = rand(r, 1:n)
        isslotfilled(s.dict, i) && i!=first && return (s.dict.keys[i], el)
    end
end

"""
    rand_dict_key(r, d)

Return a uniformly random key of the `Dict` `d` in `O(1)` expected time by
rejection-sampling filled slots of its hash table, avoiding `collect(keys(d))`.
Throws if `d` is empty.
"""
function rand_dict_key(r::AbstractRNG, d::Dict)
    isempty(d) && throw(ArgumentError("Dictionary must be non-empty"))
    n = length(d.slots)
    while true
        i = rand(r, 1:n)
        isslotfilled(d, i) && return d.keys[i]
    end
end

# rand(rng, s, 2, with_replacement=true)

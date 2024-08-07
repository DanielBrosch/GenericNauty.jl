# Basic implementation of the Schreier-Sims algorithm

# using AbstractAlgebra
import Base.in

struct TrivialGroup
    # order::Vector{Int}
    # TrivialGroup() = new(Int[])
end

mutable struct Group
    n::Int
    gen::Vector{Vector{Int}}
    b::Int # Basis element
    # SGS::Vector{Vector{Int}} # Strong generating set
    SV::Vector{Int} # Schreier Vector
    O::Vector{Int} # Orbit of b
    order::Vector{Int} # target order of basis elements (usually 1:n, does get modified when point-wise stabilizers are searched for)
    subGroup::Union{Group,TrivialGroup}
    Group() = new(-1, Vector{Int}[], -1, Int[], Int[], Int[], TrivialGroup())

    function Group(gens::Vector{Vector{Int}}, order=1:length(gens[1]))
        G = Group()
        G.order = order

        # does not remove duplicates
        if length(gens) > 0
            G.gen = gens
            G.n = length(gens[1])
            schreier_sims!(G)
        end
        return G
    end

    function Group(gen::Vector{Int}, order=1:length(gen))
        G = Group()
        G.order = order
        addGen!(G, gen)
        return G
    end
end

import Base.getproperty
# import Base.getfield
@inline function Base.getproperty(G::TrivialGroup, f::Symbol)
    @error "$f"
    f == :order && return Int[]
    f == :subGroup && return G
    f == :gen && return Vector{Int}[]
    f == :O && return Int[]
    f == :SV && return Int[]
    f == :b && return 1
    f == :n && return 1
    return Core.getfield(G, f)
end

# getproperty(::TrivialGroup, :order) = 1
# getfield(::TrivialGroup, ::Type{:order}) = 1
import Base.setproperty!
@inline Base.setproperty!(::TrivialGroup, ::Symbol, v) = begin end
# getproperty(G::TrivialGroup, ::Val{:subGroup}) = G
# getproperty(::TrivialGroup, ::Val{:gen}) = Vector{Int}[]
# getproperty(::TrivialGroup, ::Val{:O}) = Int[]
# getproperty(::TrivialGroup, ::Val{:SV}) = Int[]
# getproperty(::TrivialGroup, ::Val{:b}) = 1
# getproperty(::TrivialGroup, ::Val{:n}) = 1

function orbit(G::Group, v::Int)
    O = [v]
    i = 1
    while i <= length(O)
        @inbounds w = O[i]
        for p in G.gen
            j = p[w]
            if !(j in O)
                push!(O, j)
            end
        end
        i += 1
    end
    return O
end

function orbit!(G::Union{Group,TrivialGroup}, vs::Vector{Int})::Vector{Int}
    O::Vector{Int} = vs
    i = 1
    while i <= length(O)
        @inbounds w = O[i]
        for p in G.gen
            j = p[w]
            if !(j in O)
                push!(O, j)
            end
        end
        i += 1
    end
    return O
end

# similar to orbit, but uses inverses of G.gen, and records Schreier Vector
function orbitSchreier!(G::Union{Group,TrivialGroup})
    n = G.n
    empty!(G.O)
    push!(G.O, G.b)
    G.SV = zeros(Int, n)
    G.SV[G.b] = -1
    i = 1
    while i <= length(G.O)
        @inbounds w = G.O[i]
        for (k, p) in enumerate(G.gen)
            j = findfirst(x -> x == w, p)
            if j !== nothing # should always be true, here for type stability
                if !(j in G.O)
                    push!(G.O, j)
                    G.SV[j] = k
                end
            end
        end
        i += 1
    end
    sort!(G.O)
    return nothing
end

function findInvRepr(G::Union{Group,TrivialGroup}, v::Int)
    g = collect(1:(G.n))

    while v != G.b
        k = G.SV[v]
        if k == 0
            return Int[]
        end
        p = G.gen[k]
        g .= p[g]
        v = p[v]
    end
    return g
end

function schreier_sims!(G::Union{Group,TrivialGroup})
    # if G0 === nothing
    #     return nothing
    # end
    # G::Group = G0
    if length(G.gen) == 0
        return TrivialGroup()
    end

    oldB = G.b
    G.b = -1

    for i in G.order
        # G.gen[1] enough for SGS, but not for point-wise stabilizers
        for g in G.gen
            if g[i] != i
                G.b = i
                break
            end
        end
        G.b != -1 && break
    end
    # @show G.b
    @assert G.b != -1

    # @assert G.subGroup isa Group

    if oldB != G.b
        G2 = Group()
        G2.n = G.n
        G2.order = G.order
        G.subGroup = G2
        # G.subGroup = Group()
    else
        # G.subGroup::Group = tmp
        if G.subGroup.order != G.order
            if G.subGroup isa Group
                G.subGroup.order = G.order
                schreier_sims!(G.subGroup)
            end
        end
    end

    # @show (oldB, G.b)

    # G.SGS = G.gen

    orbitSchreier!(G)

    # @show G.SV

    rs = zeros(Int, G.n)

    for i in G.O
        r = findInvRepr(G, i)
        if length(r) == G.n
            for s in G.gen
                # rs = inv(r)*s 
                # rs s[r]
                rs[r] .= s
                rsrsbar = sift(G.subGroup, findInvRepr(G, rs[G.b])[rs])
                # if !isone(rsrsbar)
                if rsrsbar != 1:(G.n)
                    # @show G.gen
                    # @show G.SGS
                    # @show G.SV
                    # @show (r,s,rsrsbar)
                    addGen!(G.subGroup, rsrsbar)

                    # @show rsrsbar
                end
            end
        end
    end
end

function sift(G::Union{Group,TrivialGroup}, p::Vector{Int})
    if G isa TrivialGroup
        return p
    end
    if length(G.gen) == 0 || issorted(p)# == 1:length(p)
        return p
    end
    gInv = findInvRepr(G, p[G.b])

    if length(gInv) == G.n
        # p *= gInv
        p .= gInv[p]
    end

    # if G.subGroup !== nothing
    return sift(G.subGroup, p)
    # end

    return p
end

# sift(::Nothing, p::Vector{Int}) = p

# adds p to G, returns true if changed
function addGen!(G::Union{Group,TrivialGroup}, p::Vector{Int})
    if G isa TrivialGroup
        return false
    end
    q = sift(G, p)
    # if !isone(q)
    if q != 1:(G.n)
        # @info "Adding to group"
        # display(G)
        # display(p)
        # @info "adding $q"
        push!(G.gen, q)
        if G.n == -1
            G.n = length(q)
            G.order = 1:(G.n)
        end
        schreier_sims!(G)
        return true
    end
    return false
end

function SGS(G::Group)
    if G.subGroup isa TrivialGroup
        return G.gen
    end
    return union(G.gen, SGS(G.subGroup))
end

function Basis(G::Group)
    if G.subGroup.b == -1
        return [G.b]
    end
    return vcat([G.b], Basis(G.subGroup))
end

function order(G::Group)
    if G.b == -1
        return 1
    end
    return length(G.O) * order(G.subGroup)
end

function Base.in(p::Vector{Int}, G::Group)
    # isone(sift(G, p))
    return sift(G, p) == 1:(G.n)
end

function stabilizer(G::Group, S::Vector{Int})
    order = vcat(S, setdiff(1:(G.n), S))
    H = G
    while H.b in S
        H = H.subGroup
    end
    H = Group(H.gen, order)
    while H.b in S
        H = H.subGroup
    end
    return H
end

# returns same group as stabilizer(G, S), but modifies stabilizer chain of G in the process
function stabilizer!(G::Union{Group,TrivialGroup}, S::Vector{Int}, keepOrder=false)
    if G isa TrivialGroup
        return G
    end
    if keepOrder
        order = vcat(S, setdiff(1:(G.n), S))
        G.order = order
        schreier_sims!(G)
        while G.b in S
            G = G.subGroup
        end
        return G
    else
        # May change order of elements of S in the stabilizer chain
        covered = Int[]
        # G2::Group = G
        while G.b in S
            push!(covered, G.b)
            G = G.subGroup
        end
        if G isa TrivialGroup
            return G
        end
        order = vcat(covered, setdiff(S, covered), setdiff(1:(G.n), S))
        G.order = order
        schreier_sims!(G)
        while G.b in S
            G = G.subGroup
        end
        return G
    end
end

function permute!(gr::Union{Group,TrivialGroup}, per::Vector{Int})
    if gr isa TrivialGroup
        return gr
    end
    if length(gr.gen) == 0
        return gr
    end
    # @show gr.gen
    # @show p
    p2 = zero(per)
    for i in 1:length(per)
        p2[per[i]] = i
    end
    # p2 = perm(p2)
    for (i, g) in enumerate(gr.gen)
        # @show p2.d 
        # @show g.d 
        # @show per.d 
        # gr.gen[i] = p2*g*per
        gr.gen[i] .= per[g[p2]]
    end

    # G.gen .*= p
    gr.b = per[gr.b]
    gr.O .= [per[o] for o in gr.O]
    if length(gr.subGroup.gen) > 0
        permute!(gr.subGroup, per)
    end
    return gr
end

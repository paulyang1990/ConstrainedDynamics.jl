struct Graph{N}
    directchildren::Vector{Vector{Int64}}
    loopchildren::Vector{Vector{Int64}}
    ineqchildren::Vector{Vector{Int64}}
    successors::Vector{Vector{Int64}} # contains direct and loop children
    predecessors::Vector{Vector{Int64}}
    connections::Vector{Vector{Int64}}

    dfslist::SVector{N,Int64}
    rdfslist::SVector{N,Int64}

    dict::UnitDict{Base.OneTo{Int64},Int64}
    rdict::UnitDict{Base.OneTo{Int64},Int64}
    activedict::UnitDict{Base.OneTo{Int64},Bool}

    function Graph(origin::Origin,bodies::Vector{<:Body},
        eqconstraints::Vector{<:EqualityConstraint},ineqconstraints::Vector{<:InequalityConstraint})

        oid = origin.id
        adjacency, dict = adjacencyMatrix(eqconstraints, bodies)
        dfsgraph, dfslist, loops = dfs(adjacency, dict, oid)
        pat = pattern(dfsgraph, dict, loops)
        fil, originals = fillins(dfsgraph, pat, dict, loops)

        adjacency = deleteat(adjacency, dict[oid])
        dfsgraph = deleteat(dfsgraph, dict[oid])
        pat = deleteat(pat, dict[oid])
        fil = deleteat(fil, dict[oid])
        originals = deleteat(originals, dict[oid])
        dfslist = StaticArrays.deleteat(dfslist, length(dfslist))

        for (id, ind) in dict
            ind > dict[oid] && (dict[id] = ind - 1)
        end
        pop!(dict, oid)
        rdict = Dict(ind => id for (id, ind) in dict)
        activedict = Dict(id => true for (id, ind) in dict)

        for constraint in eqconstraints
            constraint.parentid == oid && (constraint.parentid = nothing)
            activedict[constraint.id] = constraint.active
        end

        N = length(dict)

        adjacency = convert(Vector{SVector{N,Bool}}, adjacency)
        dfsgraph = convert(Vector{SVector{N,Bool}}, dfsgraph)
        pat = convert(Vector{SVector{N,Bool}}, pat)
        fil = convert(Vector{SVector{N,Bool}}, fil)
        originals = convert(Vector{SVector{N,Bool}}, originals)

        dirs = directchildren(dfslist, originals, dict)
        loos = loopchildren(dfslist, fil, dict)
        ineqs = ineqchildren(dfslist, bodies, ineqconstraints, dict)
        sucs = successors(dfslist, pat, dict)
        preds = predecessors(dfslist, pat, dict)
        cons = connections(dfslist, adjacency, dict)

        dict = UnitDict(dict)
        rdict = UnitDict(rdict)

        new{N}(dirs, loos, ineqs, sucs, preds, cons, dfslist, reverse(dfslist), dict, rdict)
    end
end

function adjacencyMatrix(eqconstraints::Vector{<:EqualityConstraint}, bodies::Vector{<:Body})
    A = zeros(Bool, 0, 0)
    dict = Dict{Int64,Int64}()
    n = 0

    for constraint in eqconstraints
        cid = constraint.id
        A = [A zeros(Bool, n, 1); zeros(Bool, 1, n) zero(Bool)]
        dict[cid] = n += 1
        for bodyid in unique([constraint.parentid;constraint.childids])
            if !haskey(dict, bodyid)
                A = [A zeros(Bool, n, 1); zeros(Bool, 1, n) zero(Bool)]
                dict[bodyid] = n += 1
            end
            A[dict[cid],dict[bodyid]] = true
        end
    end
    for body in bodies # add unconnected bodies
        if !haskey(dict, body.id)
            A = [A zeros(Bool, n, 1); zeros(Bool, 1, n) zero(Bool)]
            dict[body.id] = n += 1
        end
    end

    A = A .| A'
    return convert(Matrix{Bool}, A), dict
end

function dfs(adjacency::Matrix, dict::Dict, originid::Integer)
    N = size(adjacency)[1]
    dfsgraph = zeros(Bool, N, N)
    dfslist = zeros(Int64, N)
    visited = zeros(Bool, N)
    loops = Vector{Int64}[]
    index = N

    dfslist[index] = originid
    visited[dict[originid]] = true
    dfs!(adjacency, dfsgraph, dict, dfslist, visited, loops, N, originid, -1)
    loops = loops[sortperm(sort.(loops))[1:2:length(loops)]] # removes double entries of loop connections and keeps the first found pair

    return dfsgraph, convert(SVector{N}, dfslist), loops
end

function dfs!(A::Matrix, Adfs::Matrix, dict::Dict, list::Vector, visited::Vector, loops::Vector{<:Vector{<:Integer}}, index::Integer, currentid::Integer, parentid::Integer)
    i = dict[currentid]
    for (childid, j) in dict
        if A[i,j] && parentid != childid # connection from i to j in adjacency && not a direct connection back to the parent
            if visited[j]
                push!(loops, [childid,currentid]) # childid is actually a predecessor of currentid since it's a loop
            else
                index -= 1
                list[index] = childid
                visited[j] = true
                Adfs[i,j] = true
                index = dfs!(A, Adfs, dict, list, visited, loops, index, childid, currentid)
            end
        end
    end
    return index
end

function pattern(dfsgraph::Matrix, dict::Dict, loops::Vector{<:Vector{<:Integer}})
    pat = deepcopy(dfsgraph)

    for loop in loops # loop = [index of starting constraint, index of last body in loop]
        startid = loop[1]
        endid = loop[2]
        currentid = endid
        nextid = parent(dfsgraph, dict, currentid)
        while nextid != startid
            pat[dict[startid],dict[currentid]] = true
            currentid = nextid
            nextid = parent(dfsgraph, dict, nextid)
        end
    end

    return pat
end

function fillins(dfsgraph::Matrix, pattern::Matrix, dict::Dict, loops::Vector{<:Vector{<:Integer}})
    fil = deepcopy(dfsgraph .⊻ pattern) # xor so only fillins remain (+ to be removed loop closure since this is a child)
    originals = deepcopy(dfsgraph)

    for loop in loops # loop = [index of starting constraint, index of last body in loop]
        startid = loop[1]
        endid = loop[2]
        fil[dict[startid],dict[endid]] = false
        originals[dict[startid],dict[endid]] = true
    end

    return convert(Matrix{Bool}, fil), convert(Matrix{Bool}, originals)
end

function parent(dfsgraph::Matrix, dict::Dict, childid::Integer)
    j = dict[childid]
    for (parentid, i) in dict
        dfsgraph[i,j] && (return parentid)
    end
    return -1
end

# this is done in order!
function successors(dfslist, pattern, dict::Dict)
    N = length(dfslist)
    sucs = [Int64[] for i = 1:N]
    for i = 1:N
        for cid in dfslist
            pattern[i][dict[cid]] && push!(sucs[i], cid)
        end
    end

    return sucs
end

# this is done in order!
function directchildren(dfslist, dfsgraph, dict::Dict)
    N = length(dfslist)
    dirs = [Int64[] for i = 1:N]
    for i = 1:N
        for cid in dfslist
            dfsgraph[i][dict[cid]] && push!(dirs[i], cid)
        end
    end

    return dirs
end

# this is done in order!
function loopchildren(dfslist, fillins, dict::Dict)
    N = length(dfslist)
    loos = [Int64[] for i = 1:N]
    for i = 1:N
        for cid in dfslist
            fillins[i][dict[cid]] && push!(loos[i], cid)
        end
    end

    return loos
end

function ineqchildren(dfslist, bodies, ineqconstraints, dict::Dict)
    N = length(dfslist)
    ineqs = [Int64[] for i = 1:N]
    for body in bodies
        for ineqc in ineqconstraints
            ineqc.parentid == body.id && push!(ineqs[dict[body.id]], ineqc.id)
        end
    end

    return ineqs
end

# this is done in reverse order (but this is not really important for predecessors)
function predecessors(dfslist, pattern, dict::Dict)
    N = length(dfslist)
    preds = [Int64[] for i = 1:N]
    for i = 1:N
        for cid in reverse(dfslist)
            pattern[dict[cid]][i] && push!(preds[i], cid)
        end
    end

    return preds
end

# this is done in order (but this is not really important for connections)
function connections(dfslist, adjacency, dict::Dict)
    N = length(dfslist)
    cons = [Int64[] for i = 1:N]
    for i = 1:N
        for cid in dfslist
            adjacency[i][dict[cid]] && push!(cons[i], cid)
        end
    end

    return cons
end


@inline directchildren(graph, id::Integer) = graph.directchildren[graph.dict[id]]
@inline loopchildren(graph, id::Integer) = graph.loopchildren[graph.dict[id]]
@inline ineqchildren(graph, id::Integer) = graph.ineqchildren[graph.dict[id]]
@inline successors(graph, id::Integer) = graph.successors[graph.dict[id]]
@inline predecessors(graph, id::Integer) = graph.predecessors[graph.dict[id]]
@inline connections(graph, id::Integer) = graph.connections[graph.dict[id]]
@inline isactive(graph, id::Integer) = graph.activedict[id]

@inline function hassuccessor(graph::Graph{N}, id, cid) where N
    for val in graph.successors[graph.dict[id]]
        val == cid && (return true)
    end
    return false
end

@inline function haspredecessor(graph::Graph{N}, id, pid) where N
    for val in graph.predecessors[graph.dict[id]]
        val == pid && (return true)
    end
    return false
end

@inline function hasdirectchild(graph::Graph{N}, id, cid) where N
    for val in graph.directchildren[graph.dict[id]]
        val == cid && (return true)
    end
    return false
end

@inline function activate!(graph::Graph{N}, id::Integer) where N
    graph.activedict[id] = true
    return
end

@inline function deactivate!(graph::Graph{N}, id::Integer) where N
    graph.activedict[id] = false
    return
end
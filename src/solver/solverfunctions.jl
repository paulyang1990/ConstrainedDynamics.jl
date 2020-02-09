@inline function setDandŝ!(diagonal::DiagonalEntry,body::Body,mechanism::Mechanism)
    diagonal.D = ∂dyn∂vel(body, mechanism.dt)
    diagonal.ŝ = dynamics(body, mechanism)
    return
end

@inline function setDandŝ!(d::DiagonalEntry{T,N},c::EqualityConstraint,mechanism::Mechanism) where {T,N}
    d.D = @SMatrix zeros(T,N,N)
    # μ = 1e-05
    # d.D = SMatrix{N,N,T,N*N}(μ*I)
    d.ŝ = g(c,mechanism)
    return
end

@inline function setLU!(o::OffDiagonalEntry,bodyid::Int64,c::EqualityConstraint,mechanism)
    o.L = -∂g∂pos(c,bodyid,mechanism)'
    o.U = ∂g∂vel(c,bodyid,mechanism)
    return
end

@inline function setLU!(o::OffDiagonalEntry,c::EqualityConstraint,bodyid::Int64,mechanism)
    o.L = ∂g∂vel(c,bodyid,mechanism)
    o.U = -∂g∂pos(c,bodyid,mechanism)'
    return
end

@inline function setLU!(o::OffDiagonalEntry{T,N1,N2}) where {T,N1,N2}
    o.L = @SMatrix zeros(T,N2,N1)
    o.U = o.L'
    return
end

@inline function updateLU1!(o::OffDiagonalEntry,d::DiagonalEntry,gc::OffDiagonalEntry,cgc::OffDiagonalEntry)
    D = d.D
    o.L -= gc.L*D*cgc.U
    o.U -= cgc.L*D*gc.U
    return
end

@inline function updateLU2!(o::OffDiagonalEntry,d::DiagonalEntry)
    Dinv = d.Dinv
    o.L = o.L*Dinv
    o.U = Dinv*o.U
    return
end

@inline function updateD!(d::DiagonalEntry,c::DiagonalEntry,f::OffDiagonalEntry)
    d.D -= f.L*c.D*f.U
    return
end

function invertD!(d::DiagonalEntry)
    d.Dinv = inv(d.D)
    return
end

@inline function LSol!(d::DiagonalEntry,child::DiagonalEntry,fillin::OffDiagonalEntry)
    d.ŝ -= fillin.L*child.ŝ
    return
end

function DSol!(d::DiagonalEntry)
    d.ŝ = d.Dinv*d.ŝ
    return
end

@inline function USol!(d::DiagonalEntry,parent::DiagonalEntry,fillin::OffDiagonalEntry)
    d.ŝ -= fillin.U*parent.ŝ
    return
end


function factor!(graph::Graph,ldu::SparseLDU)
    for id in graph.dfslist
        sucs = successors(graph,id)
        for cid in sucs
            offdiagonal = getentry(ldu,(id,cid))
            for gcid in sucs
                gcid == cid && break
                if hasdirectchild(graph,cid,gcid)
                    updateLU1!(offdiagonal,getentry(ldu,gcid),getentry(ldu,(id,gcid)),getentry(ldu,(cid,gcid)))
                end
            end
            updateLU2!(offdiagonal,getentry(ldu,cid))
        end

        diagonal = getentry(ldu,id)

        for cid in successors(graph,id)
            updateD!(diagonal,getentry(ldu,cid),getentry(ldu,(id,cid)))
        end
        invertD!(diagonal)
    end
end

function solve!(graph::Graph,ldu::SparseLDU)
    dfslist = graph.dfslist

    for id in dfslist
        diagonal = getentry(ldu,id)

        for cid in successors(graph,id)
            LSol!(diagonal,getentry(ldu,cid),getentry(ldu,(id,cid)))
        end
    end

    for id in graph.rdfslist
        diagonal = getentry(ldu,id)

        DSol!(diagonal)

        for pid in predecessors(graph,id)
            USol!(diagonal,getentry(ldu,pid),getentry(ldu,(pid,id)))
        end
    end
end

@inline update!(component::Component,ldu::SparseLDU,αsmax,αγmax) = update!(component,getentry(ldu,component.id),αsmax,αγmax)
# function update!(component::Component,diagonal::DiagonalEntry)
#     component.s1 = component.s0 - diagonal.ŝ
#     return
# end
function update!(component::EqualityConstraint,diagonal::DiagonalEntry,αsmax,αγmax)
    component.s1 = component.s0 - αγmax*diagonal.ŝ
    return
end
function update!(component::Body,diagonal::DiagonalEntry,αsmax,αγmax)
    component.s1 = component.s0 - αsmax*diagonal.ŝ
    component.sl1 = component.sl0 - αsmax*diagonal.sl
    component.ga1 = component.ga0 - αγmax*diagonal.ga
    return
end

@inline function s0tos1!(component::EqualityConstraint)
    component.s1 = component.s0
    return
end

@inline function s1tos0!(component::EqualityConstraint)
    component.s0 = component.s1
    return
end

@inline function s0tos1!(component::Body)
    component.s1 = component.s0
    component.sl1 = component.sl0
    component.ga1 = component.ga0
    return
end

@inline function s1tos0!(component::Body)
    component.s0 = component.s1
    component.sl0 = component.sl1
    component.ga0 = component.ga1
    return
end

@inline function normΔs(component::Component)
    difference = component.s1-component.s0
    return dot(difference,difference)
end


function computeΔ!(body::Body,diagonal::DiagonalEntry,mechanism::Mechanism)
    dt = mechanism.dt
    Nx = SVector{6,Float64}(0,0,1,0,0,0)'
    Nv = dt*Nx
    γ = body.ga1
    s = body.sl1
    Σ = γ/s
    Σm = s/γ
    μ = mechanism.μ
    φ = body.x[2][3]+dt*body.s1[3]

    Δv = diagonal.ŝ
    diagonal.sl = Σm*(γ - diagonal.ga) - μ/γ
    diagonal.ga = Σ*(φ - Nv*Δv) - μ/s

    return
end

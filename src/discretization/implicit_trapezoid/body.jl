@inline function dynamics(mechanism, body::Body{T}) where T
    state = body.state
    Δt = mechanism.Δt
    graph = mechanism.graph

    ezg = SVector{3,T}(0, 0, -mechanism.g)
    dynT = body.m * ((state.vsol[2] - state.vc) / Δt + ezg) - 1/2 * (state.Fk[1] + state.Fk[2])

    J = body.J
    ω1 = state.ωc
    ω2 = state.ωsol[2]
    sq1 = sqrt(4 / Δt^2 - ω1' * ω1)
    sq2 = sqrt(4 / Δt^2 - ω2' * ω2)
    dynR = skewplusdiag(ω2, sq2) * (J * ω2) - skewplusdiag(ω1, sq1) * (J * ω1) - (state.τk[1] + state.τk[2])

    state.d = [dynT;dynR]

    for cid in connections(mechanism.graph, body.id)
        isinactive(graph, cid) && continue
        GtλTof!(mechanism, body, geteqconstraint(mechanism, cid))
    end

    for cid in ineqchildren(mechanism.graph, body.id)
        isinactive(graph, cid) && continue
        NtγTof!(mechanism, body, getineqconstraint(mechanism, cid))
    end

    return state.d
end

@inline function ∂dyn∂vel(body::Body{T}, Δt) where T
    J = body.J
    ω2 = body.state.ωsol[2]
    sq = sqrt(4 / Δt^2 - ω2' * ω2)

    dynT = SMatrix{3,3,T,9}(body.m / Δt * I)
    dynR = skewplusdiag(ω2, sq) * J - J * ω2 * (ω2' / sq) - skew(J * ω2)

    Z = @SMatrix zeros(T, 3, 3)

    return [[dynT; Z] [Z; dynR]]
end


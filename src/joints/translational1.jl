@inline function getPositionDelta(joint::Translational1, body1::AbstractBody, body2::Body{T}, x::SVector{2,T}) where T
    Δx = joint.V12' * x # in body1 frame
    return Δx
end

@inline function getVelocityDelta(joint::Translational1, body1::AbstractBody, body2::Body{T}, v::SVector{2,T}) where T
    Δv = joint.V12' * v # in body1 frame
    return Δv
end

@inline function setForce!(joint::Translational1, body1::Body, body2::Body{T}, F::SVector{2,T}, No) where T
    clearForce!(joint, body1, body2, No)

    q1 = body1.state.qk[No]
    q2 = body2.state.qk[No]

    F1 = vrotate(joint.V12' * -F, q1)
    F2 = -F1

    τ1 = vrotate(torqueFromForce(F1, vrotate(joint.vertices[1], q1)),inv(q1)) # in local coordinates
    τ2 = vrotate(torqueFromForce(F2, vrotate(joint.vertices[2], q2)),inv(q2)) # in local coordinates

    updateForce!(joint, body1, body2, F1, τ1, F2, τ2, No)
    return
end

@inline function setForce!(joint::Translational1, body1::Origin, body2::Body{T}, F::SVector{2,T}, No) where T
    clearForce!(joint, body2, No)

    q2 = body2.state.qk[No]

    F2 = joint.V12' * F
    τ2 = vrotate(torqueFromForce(F2, vrotate(joint.vertices[2], q2)),inv(q2)) # in local coordinates

    updateForce!(joint, body2, F2, τ2, No)
    return
end


@inline function minimalCoordinates(joint::Translational1, body1::Body, body2::Body, No)
    vertices = joint.vertices
    q1 = body1.state.qk[No]
    joint.V12 * vrotate(body2.state.xk[No] + vrotate(vertices[2], body2.state.qk[No]) - (body1.state.xk[No] + vrotate(vertices[1], q1)), inv(q1))
end

@inline function minimalCoordinates(joint::Translational1, body1::Origin, body2::Body, No)
    vertices = joint.vertices
    joint.V12 * (body2.state.xk[No] + vrotate(vertices[2], body2.state.qk[No]) - vertices[1])
end


@inline g(joint::Translational1, body1::Body, body2::Body, Δt) = joint.V3 * g(joint, body1.state, body2.state, Δt)
@inline g(joint::Translational1, body1::Origin, body2::Body, Δt) = joint.V3 * g(joint, body2.state, Δt)


@inline function ∂g∂posa(joint::Translational1, body1::Body, body2::Body)
    if body2.id == joint.cid
        return joint.V3 * ∂g∂posa(joint, body1.state, body2.state)
    else
        return ∂g∂posa(joint)
    end
end

@inline function ∂g∂posb(joint::Translational1, body1::Body, body2::Body)
    if body2.id == joint.cid
        return joint.V3 * ∂g∂posb(joint, body1.state, body2.state)
    else
        return ∂g∂posb(joint)
    end
end

@inline function ∂g∂posb(joint::Translational1, body1::Origin, body2::Body)
    if body2.id == joint.cid
        return joint.V3 * ∂g∂posb(joint, body2.state)
    else
        return ∂g∂posb(joint)
    end
end


@inline function ∂g∂vela(joint::Translational1, body1::Body, body2::Body, Δt)
    if body2.id == joint.cid
        return joint.V3 * ∂g∂vela(joint, body1.state, body2.state, Δt)
    else
        return ∂g∂vela(joint)
    end
end

@inline function ∂g∂velb(joint::Translational1, body1::Body, body2::Body, Δt)
    if body2.id == joint.cid
        return joint.V3 * ∂g∂velb(joint, body1.state, body2.state, Δt)
    else
        return ∂g∂velb(joint)
    end
end

@inline function ∂g∂velb(joint::Translational1, body1::Origin, body2::Body, Δt)
    if body2.id == joint.cid
        return joint.V3 * ∂g∂velb(joint, body2.state, Δt)
    else
        return ∂g∂velb(joint)
    end
end

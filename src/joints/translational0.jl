@inline function getVelocityDelta(joint::Translational0, body1::AbstractBody, body2::Body{T}, v::SVector{3,T}) where T
    Δv = v # in body1 frame
    return Δv
end

@inline function getPositionDelta(joint::Translational0, body1::AbstractBody, body2::Body{T}, x::SVector{3,T}) where T
    Δx = x # in body1 frame
    return Δx
end

@inline function setForce!(joint::Translational0, body1::Body, body2::Body{T}, F::SVector{3,T}, No) where T
    clearForce!(joint, body1, body2, No)

    q1 = body1.q[No]
    q2 = body2.q[No]

    F1 = vrotate(-F, q1)
    F2 = -F1

    τ1 = torqueFromForce(F1, vrotate(joint.vertices[1], q1))
    τ2 = torqueFromForce(F2, vrotate(joint.vertices[2], q2))

    updateForce!(joint, body1, body2, F1, τ1, F2, τ2, No)
    return
end

@inline function setForce!(joint::Translational0, body1::Origin, body2::Body{T}, F::SVector{3,T}, No) where T
    clearForce!(joint, body2, No)

    F2 = F
    τ2 = torqueFromForce(F2, vrotate(joint.vertices[2], body2.q[No]))

    updateForce!(joint, body2, F2, τ2, No)
    return
end


@inline function minimalCoordinates(joint::Translational0, body1::AbstractBody, body2::AbstractBody, No)
    body2.x[No]
end


@inline g(joint::Translational0, body1::AbstractBody, body2::AbstractBody, Δt, No) = g(joint)


@inline ∂g∂posa(joint::Translational0, body1::AbstractBody, body2::AbstractBody, No) = ∂g∂posa(joint)
@inline ∂g∂posb(joint::Translational0, body1::AbstractBody, body2::AbstractBody, No) = ∂g∂posb(joint)
@inline ∂g∂vela(joint::Translational0, body1::AbstractBody, body2::AbstractBody, Δt, No) = ∂g∂vela(joint)
@inline ∂g∂velb(joint::Translational0, body1::AbstractBody, body2::AbstractBody, Δt, No) = ∂g∂velb(joint)

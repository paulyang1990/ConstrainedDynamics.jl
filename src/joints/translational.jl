mutable struct Translational{T,N} <: Joint{T,N}
    V3::Adjoint{T,SVector{3,T}} # in body1's frame
    V12::SMatrix{2,3,T,6} # in body1's frame
    vertices::NTuple{2,SVector{3,T}} # in body1's & body2's frames
    
    F::SVector{3,T}
    τ::SVector{3,T}

    childid::Int64

    function Translational{T,N}(body1::AbstractBody, body2::AbstractBody;
            p1::AbstractVector = zeros(3), p2::AbstractVector = zeros(3), axis::AbstractVector = zeros(3)
        ) where {T,N}
        
        vertices = (p1, p2)
        V1, V2, V3 = orthogonalrows(axis)
        V12 = [V1;V2]

        F = zeros(T,3)
        τ = zeros(T,3)

        childid = body2.id

        new{T,N}(V3, V12, vertices, F, τ, childid), body1.id, body2.id
    end
end

Translational0 = Translational{T,0} where T
Translational1 = Translational{T,1} where T
Translational2 = Translational{T,2} where T
Translational3 = Translational{T,3} where T


# Position level constraints

@inline function g(joint::Translational, xa::AbstractVector, qa::UnitQuaternion, xb::AbstractVector, qb::UnitQuaternion)
    vertices = joint.vertices
    return vrotate(xb + vrotate(vertices[2], qb) - (xa + vrotate(vertices[1], qa)), inv(qa))
end
@inline function g(joint::Translational, xb::AbstractVector, qb::UnitQuaternion)
    vertices = joint.vertices
    return xb + vrotate(vertices[2], qb) - vertices[1]
end


# Derivatives NOT accounting for quaternion specialness

@inline function ∂g∂posa(joint::Translational, xa::AbstractVector, qa::UnitQuaternion, xb::AbstractVector, qb::UnitQuaternion)
    point2 = xb + vrotate(joint.vertices[2], qb)

    X = -VLᵀmat(qa) * RVᵀmat(qa)
    Q = 2 * VLᵀmat(qa) * (Lmat(UnitQuaternion(point2)) - Lmat(UnitQuaternion(xa)))

    return X, Q
end
@inline function ∂g∂posb(joint::Translational, xa::AbstractVector, qa::UnitQuaternion, xb::AbstractVector, qb::UnitQuaternion)
    X = VLᵀmat(qa) * RVᵀmat(qa)
    Q = 2 * VLᵀmat(qa) * Rmat(qa) * Rᵀmat(qb) * Rmat(UnitQuaternion(joint.vertices[2]))

    return X, Q
end
@inline function ∂g∂posb(joint::Translational, xb::AbstractVector, qb::UnitQuaternion)
    X = I
    Q = 2 * VRᵀmat(qb) * Rmat(UnitQuaternion(joint.vertices[2]))

    return X, Q
end
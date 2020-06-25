mutable struct Impact{T} <: Contact{T}
    Nx::Adjoint{T,SVector{6,T}}
    offset::SVector{6,T}


    function Impact(body::Body{T}, normal::AbstractVector; offset::AbstractVector = zeros(3)) where T
        # Derived from plane equation a*v1 + b*v2 + distance*v3 = p - offset
        V1, V2, V3 = orthogonalcols(normal)
        A = [V1 V2 V3] # gives two plane vectors
        Ainv = inv(A)
        ainv3 = Ainv[3,SA[1; 2; 3]]
        Nx = [ainv3;0.0;0.0;0.0]
        offset = [offset;0.0;0.0;0.0]

        new{T}(Nx, offset), body.id
    end
end

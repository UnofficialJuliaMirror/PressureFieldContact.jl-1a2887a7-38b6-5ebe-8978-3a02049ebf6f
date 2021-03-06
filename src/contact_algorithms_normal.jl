
function normal_wrench(b::TypedElasticBodyBodyCache{T}) where {T}
    wrench_lin = zeros(SVector{3,T})
    wrench_ang = zeros(SVector{3,T})
    @inbounds begin
    for k_trac = 1:length(b.TractionCache)
        trac = b.TractionCache[k_trac]
        p_dA = calc_p_dA(trac)
        λ_s = p_dA * trac.n̂
        wrench_lin += λ_s
        wrench_ang += cross(trac.r_cart, λ_s)
    end
    end
    return Wrench(b.mesh_2.FrameID, wrench_ang, wrench_lin)
end

function normal_wrench_cop(b::TypedElasticBodyBodyCache{T}) where {T}
    wrench_lin = zeros(SVector{3,T})
    wrench_ang = zeros(SVector{3,T})
    int_p_dA_cop = zeros(SVector{3,T})
    int_p_dA = zero(T)
    @inbounds begin
    for k_trac = 1:length(b.TractionCache)
        trac = b.TractionCache[k_trac]
        p_dA = calc_p_dA(trac)
        λ_s = p_dA * trac.n̂
        wrench_lin += λ_s
        wrench_ang += cross(trac.r_cart, λ_s)
        int_p_dA += p_dA
        int_p_dA_cop += p_dA * trac.r_cart
    end
    end
    return Point3D(b.mesh_2.FrameID, int_p_dA_cop / int_p_dA), Wrench(b.mesh_2.FrameID, wrench_ang, wrench_lin)
end

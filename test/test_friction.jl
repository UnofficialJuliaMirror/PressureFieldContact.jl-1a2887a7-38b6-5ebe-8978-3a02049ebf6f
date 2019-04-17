@testset "transform_stiffness" begin
    f2 = CartesianFrame3D()
    f3 = CartesianFrame3D()
    I3 = @SMatrix([9.0 2.0 1.0; 2.0 8.0 3.0; 1.0 3.0 7.0])
    inertia_pre = SpatialInertia{Float64}(f2, I3, randn(SVector{3,Float64}), 1.5)
    xform = Transform3D(f2, f3, rand(RotMatrix{3,Float64}), rand(SVector{3,Float64}))
    i66 = SMatrix(transform(inertia_pre, xform))

    s = spatialStiffness{Float64}()
    s.K.data .= SMatrix(inertia_pre)
    SoftContact.transform_stiffness!(s, xform)

    @test i66 ≈ s.K
end

@testset "calc_K_sqrt⁻¹" begin
    s = spatialStiffness{Float64}()
    s.K.data .= rand_pd(6)
    SoftContact.calc_K_sqrt⁻¹!(s)
    @test s.K⁻¹_sqrt ≈ sqrt(inv(s.K))
end

@testset "bristle friction" begin
    ### Box properties
    box_rad = 0.05
    i_prop_compliant = InertiaProperties(400.0)
    i_prop_rigid     = InertiaProperties(400.0, d=0.09)
    Ē = 1.0e9
    c_prop_compliant = ContactProperties(Ē=Ē)
    eM_box_rigid     = as_tri_eMesh(output_eMesh_box(box_rad))
    eM_box_compliant = output_eMesh_box(box_rad)

    ### Create mechanism and temporary structure
    my_mechanism = Mechanism(RigidBody{Float64}("world"); gravity=SVector{3,Float64}(0.0, 0.0, -9.8054))  # create empty mechanism
    ts = TempContactStruct(my_mechanism)

    name_part = "part"
    # eM_box = output_eMesh_box(box_rad .* SVector{3,Float64}(1.0, 1.0, 20.0))
    # eMesh_transform!(eM_box, box_rad * SVector{3,Float64}(0.0, 0.0, -20.0))
	eM_box = output_eMesh_half_plane(1.0)
    nt_part = add_body_contact!(ts, name_part, as_tri_eMesh(eM_box), nothing, i_prop_rigid)

    name_hol_1 = "hol_1"
    hol_rad = 0.2 * box_rad
    eM_hol_1 = output_eMesh_box(hol_rad * ones(SVector{3,Float64}))
    # eMesh_transform!(eM_hol_1, SVector{3,Float64}(box_rad + hol_rad, 0.0, 0.0))
	eMesh_transform!(eM_hol_1, SVector{3,Float64}(0.0, 0.0, hol_rad))  # box_rad + hol_rad, 0.0, 0.0))

	# eMesh_transform!(eM_box, box_rad * SVector(0.0, 0, +1))
    joint_1 = Prismatic(SVector{3,Float64}(0.0, 0.0, 1.0))
    nt_hol_1 = add_body_contact!(ts, name_hol_1, eM_hol_1, c_prop_compliant, i_prop_compliant, joint_type=joint_1)

    τ = 0.03
    k̄ = 1.0e6
    add_pair_rigid_compliant_bristle!(ts, nt_part.mesh_id, nt_hol_1.mesh_id, μ=0.3, χ=0.6, k̄=k̄, τ=τ)

    mech_scen = MechanismScenario(ts, calcXd!, n_quad_rule=2)
    pene = hol_rad * 0.001
    set_configuration!(mech_scen.float.state, nt_hol_1.joint, [-pene])
    x = get_state(mech_scen)

	# #######################
	# if !@isdefined vis  ### Add meshcat visualizer
	# 	vis = Visualizer()
	# 	open(vis)
	# end
	# color_gray  = RGBA{Float32}(0.5, 0.5, 0.5, 1.0)
	# color_blue  = RGBA{Float32}(0.0, 0.0, 1.0, 1.0)
	# mvis = MechanismVisualizer(my_mechanism, vis)
	# set_mesh_visual!(mvis, mech_scen, nt_hol_1.mesh_id, color_blue)
	# set_mesh_visual!(mvis, mech_scen, nt_part.mesh_id,  color_gray)
	# set_configuration!(mech_scen, mvis, x)
	# #######################

    ### Test 1 -- see if stiffness is what is expected
    calcXd!(get_state(mech_scen), x, mech_scen)
    K_ana = (hol_rad^2) * 4 * k̄ * (Ē * (pene / hol_rad))
    Kʷ = mech_scen.float.bodyBodyCache.spatialStiffness.K
	K_44 = Kʷ[4,4]
	K_55 = Kʷ[5,5]
	@test K_44 == K_55
    @test 0.99 * K_ana < K_55 < 1.01 * K_ana

    ### Test 2 -- see if stiffness was decomposed correctly
    tm = mech_scen.float
    b  = tm.bodyBodyCache
    spaStiff = b.spatialStiffness

    ### Test 3 -- see if spring force calculated both ways agrees
    c_ins = mech_scen.ContactInstructions[1]
    SoftContact.force_single_elastic_intersection!(mech_scen, tm, c_ins)  # populate the cache
    SoftContact.calc_K_sqrt⁻¹!(spaStiff)
    Δ² = (rand(SVector{6,Float64}) + 0.5) * 1.0e-8

    s = SoftContact.set_s_from_Δʷ(mech_scen, c_ins, Δ²)
    mech_scen.float.s.segments[c_ins.FrictionModel.BristleID] .= s
    _, wrench²_fric = SoftContact.bristle_wrench_in_world(tm,  c_ins)
    wrench²_fric = as_static_vector(wrench²_fric)
    wrench²_fric_2 = - spaStiff.K * Δ²
    @test (0.999999 <  dot(normalize(wrench²_fric), normalize(wrench²_fric_2)))
end

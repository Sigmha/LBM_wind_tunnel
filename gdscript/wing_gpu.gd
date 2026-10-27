extends Node
class_name WingGpu

var c: WingConfig
var s: WingState
var rd: RenderingDevice
var buf_a: RID
var buf_b: RID
var buf_solid: RID
var mask_shader: RID
var mask_pipeline: RID
var mask_set: RID
var mpc := PackedByteArray()
var shader: RID
var pipeline: RID
var buf_force: RID
var img: RID
var sets: Array[RID] = []
var pc := PackedByteArray()
var smoke_shader: RID
var smoke_pipeline: RID
var smoke_a: RID
var smoke_b: RID
var smoke_img: RID
var smoke_sets: Array[RID] = []
var spc := PackedByteArray()
var smoke_step := 0
var smoke_tex: Texture2DRD
var vmax_seen := 0.0
var taum: float

func _init(state: WingState, config: WingConfig) -> void:
	s = state
	c = config
	rd = RenderingServer.get_rendering_device()

func setup_solid_buffer():
	# Setup Solid buffer
	var mask_bytes := PackedByteArray()
	mask_bytes.resize(c.N * 4)                      # zéros : le shader de masque le remplit à la 1re frame
	buf_solid = rd.storage_buffer_create(mask_bytes.size(), mask_bytes)
	var mspirv: RDShaderSPIRV = (load("res://glsl/wing_mask.glsl") as RDShaderFile).get_spirv()
	if mspirv.compile_error_compute != "":
		push_error(mspirv.compile_error_compute)
		return
	mask_shader = rd.shader_create_from_spirv(mspirv)
	mask_pipeline = rd.compute_pipeline_create(mask_shader)
	var u_m := RDUniform.new()
	u_m.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	u_m.binding = 0
	u_m.add_id(buf_solid)
	mask_set = rd.uniform_set_create([u_m], mask_shader, 0)
	mpc.resize(32)
	mpc.encode_s32(0, c.NX)
	mpc.encode_s32(4, c.NY)
	mpc.encode_float(16, c.XP)
	mpc.encode_float(20, c.YP)
	mpc.encode_float(24, c.C)
	mpc.encode_float(28, c.T_REL)

func setup_physics_buffer():
	# Setup Physics buffer
	var spirv: RDShaderSPIRV = (load("res://glsl/wing_physics.glsl") as RDShaderFile).get_spirv()
	if spirv.compile_error_compute != "":
		push_error(spirv.compile_error_compute)
		return
	shader = rd.shader_create_from_spirv(spirv)
	pipeline = rd.compute_pipeline_create(shader)
	# Distributions : équilibre uniforme à u = 0 (la rampe démarre à 0)
	var f0 := PackedFloat32Array()
	f0.resize(9 * c.N)
	var bytes := f0.to_byte_array()
	buf_a = rd.storage_buffer_create(bytes.size(), bytes)
	buf_b = rd.storage_buffer_create(bytes.size(), bytes)
	
	var zero := PackedByteArray()
	zero.resize(16)
	buf_force = rd.storage_buffer_create(16, zero)

	# Image de sortie
	var fmt := RDTextureFormat.new()
	fmt.width = c.NX
	fmt.height = c.NY
	fmt.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	fmt.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT \
		| RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT \
		| RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT \
		| RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	img = rd.texture_create(fmt, RDTextureView.new(), [])
	rd.texture_clear(img, Color(0, 0, 0, 0), 0, 1, 0, 1)

	for pair in [[buf_a, buf_b], [buf_b, buf_a]]:
		var u_in := RDUniform.new()
		u_in.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
		u_in.binding = 0
		u_in.add_id(pair[0])
		var u_out := RDUniform.new()
		u_out.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
		u_out.binding = 1
		u_out.add_id(pair[1])
		var u_sol := RDUniform.new()
		u_sol.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
		u_sol.binding = 2
		u_sol.add_id(buf_solid)
		var u_img := RDUniform.new()
		u_img.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
		u_img.binding = 3
		u_img.add_id(img)
		var u_f := RDUniform.new()
		u_f.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
		u_f.binding = 4
		u_f.add_id(buf_force)
		sets.append(rd.uniform_set_create([u_in, u_out, u_sol, u_img, u_f], shader, 0))

	pc.resize(32)
	pc.encode_s32(0, c.NX)
	pc.encode_s32(4, c.NY)
	pc.encode_float(12, 0.0)
	pc.encode_s32(20, c.PROBE_Y * c.NX + c.PROBE_X)
	pc.encode_s32(24, 1)

func setup_smoke_buffer():
	# Setup fumee buffer
	var sspirv: RDShaderSPIRV = (load("res://glsl/smoke_physics.glsl") as RDShaderFile).get_spirv()
	if sspirv.compile_error_compute != "":
		push_error(sspirv.compile_error_compute)
		return
	smoke_shader = rd.shader_create_from_spirv(sspirv)
	smoke_pipeline = rd.compute_pipeline_create(smoke_shader)

	var zeros := PackedByteArray()
	zeros.resize(c.N * 4)                              # N floats à 0
	smoke_a = rd.storage_buffer_create(zeros.size(), zeros)
	smoke_b = rd.storage_buffer_create(zeros.size(), zeros)

	var sfmt := RDTextureFormat.new()
	sfmt.width = c.NX
	sfmt.height = c.NY
	sfmt.format = RenderingDevice.DATA_FORMAT_R32_SFLOAT
	sfmt.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT \
		| RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT \
		| RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT
	smoke_img = rd.texture_create(sfmt, RDTextureView.new(), [])
	rd.texture_clear(smoke_img, Color(0, 0, 0, 0), 0, 1, 0, 1)

	for pair in [[smoke_a, smoke_b], [smoke_b, smoke_a]]:
		var s0 := RDUniform.new()
		s0.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
		s0.binding = 0
		s0.add_id(pair[0])
		var s1 := RDUniform.new()
		s1.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
		s1.binding = 1
		s1.add_id(pair[1])
		var s2 := RDUniform.new()
		s2.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
		s2.binding = 2
		s2.add_id(buf_solid)
		var s3 := RDUniform.new()
		s3.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
		s3.binding = 3
		s3.add_id(img)
		var s4 := RDUniform.new()
		s4.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
		s4.binding = 4
		s4.add_id(smoke_img)
		smoke_sets.append(rd.uniform_set_create([s0, s1, s2, s3, s4], smoke_shader, 0))

	spc.resize(32)
	spc.encode_s32(0, c.NX)
	spc.encode_s32(4, c.NY)
	spc.encode_s32(8, c.SMOKE_SPACING)
	spc.encode_s32(12, c.SMOKE_THICK)
	spc.encode_float(16, float(s.substeps_tick))

	smoke_tex = Texture2DRD.new()
	smoke_tex.texture_rd_rid = smoke_img             # une seule fois

func setup_shader():
	var tex := Texture2DRD.new()
	tex.texture_rd_rid = img
	s.disp.texture = tex
	s.disp.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	s.disp.stretch_mode = TextureRect.STRETCH_SCALE
	s.disp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.disp.position = Vector2(10, 10)
	s.disp.size = Vector2(c.NX * c.SCALE, c.NY * c.SCALE)
	s.mat = ShaderMaterial.new()
	s.mat.shader = load("res://colormap_uy.gdshader")
	s.mat.set_shader_parameter("vmax", 0.03)
	s.mat.set_shader_parameter("wmax", 0.004)
	s.mat.set_shader_parameter("smoke_tex", smoke_tex)
	s.mat.set_shader_parameter("mode", s.disp_mode)
	s.disp.material = s.mat

func compute_physics():
	rd.buffer_clear(buf_force, 0, 16)
	var cl := rd.compute_list_begin()

	if s.mask_dirty:
		var a := deg_to_rad(s.alpha_deg)
		mpc.encode_float(8, cos(a))
		mpc.encode_float(12, sin(a))
		rd.compute_list_bind_compute_pipeline(cl, mask_pipeline)
		rd.compute_list_bind_uniform_set(cl, mask_set, 0)
		rd.compute_list_set_push_constant(cl, mpc, mpc.size())
		rd.compute_list_dispatch(cl, ceili(c.NX / 8.0), ceili(c.NY / 8.0), 1)
		rd.compute_list_add_barrier(cl)
		s.mask_dirty = false

	rd.compute_list_bind_compute_pipeline(cl, pipeline)
	spc.encode_float(16, float(s.substeps_tick))
	for k in s.substeps_tick:
		var s_coef := minf(float(s.step) / c.T_RAMP, 1.0)
		pc.encode_float(12, c.U_IN * 0.5 * (1.0 - cos(PI * s_coef)))
		pc.encode_s32(24, 1 if k == s.substeps_tick - 1 else 0)
		rd.compute_list_bind_uniform_set(cl, sets[s.step % 2], 0)
		rd.compute_list_set_push_constant(cl, pc, pc.size())
		rd.compute_list_dispatch(cl, ceili(c.NX / 32.0), ceili(c.NY / 4.0), 1)
		rd.compute_list_add_barrier(cl)
		s.step += 1
	# Fumée : 1 passe par frame, dt = SUBSTEPS pas
	rd.compute_list_bind_compute_pipeline(cl, smoke_pipeline)
	rd.compute_list_bind_uniform_set(cl, smoke_sets[smoke_step % 2], 0)
	rd.compute_list_set_push_constant(cl, spc, spc.size())
	rd.compute_list_dispatch(cl, ceili(c.NX / 8.0), ceili(c.NY / 8.0), 1)
	rd.compute_list_add_barrier(cl)
	smoke_step += 1
	rd.compute_list_end()

func apply_re(re: float) -> void:
	s.nu_lat = c.U_IN * c.C / re
	s.tau = 3.0 * s.nu_lat + 0.5
	taum = s.tau if c.LAMBDA < 0.0 else 0.5 + c.LAMBDA / (s.tau - 0.5)
	pc.encode_float(8, s.tau)
	pc.encode_float(16, taum)

func update_re() -> void:
	var e := log(s.re_target / s.re_cur)
	if absf(e) < 1e-6:
		return
	s.re_cur *= exp(clampf(e, -c.RE_RATE, c.RE_RATE))
	apply_re(s.re_cur)
	s.settle_until = s.step + c.SETTLE      # tant que Re bouge : « transitoire », moyennes remises à zéro
	s.cd_sum = 0.0
	s.cl_sum = 0.0
	s.cd_n = 0

func sample() -> void:
	var fb := rd.buffer_get_data(buf_force)
	var v := fb.decode_s32(8) / 1.0e7
	vmax_seen = maxf(vmax_seen, absf(v))
	var fx: float = fb.decode_s32(0) / c.FORCE_SCALE / s.substeps_tick
	var fy: float = fb.decode_s32(4) / c.FORCE_SCALE / s.substeps_tick
	s.cd = 2.0 * fx / (c.U_IN * c.U_IN * c.C)
	s.cl = 2.0 * fy / (c.U_IN * c.U_IN * c.C)
	s.settled = s.step > s.settle_until
	if s.settled:
		s.cd_sum += s.cd
		s.cl_sum += s.cl
		s.cd_n += 1

func _exit_tree() -> void:
	rd.free_rid(mask_set)
	rd.free_rid(mask_pipeline)
	rd.free_rid(mask_shader)
	for k in sets:
		rd.free_rid(k)
	rd.free_rid(pipeline)
	rd.free_rid(shader)
	rd.free_rid(buf_a)
	rd.free_rid(buf_b)
	rd.free_rid(buf_solid)
	rd.free_rid(img)
	for k in smoke_sets:
		rd.free_rid(k)
	rd.free_rid(smoke_pipeline)
	rd.free_rid(smoke_shader)
	rd.free_rid(smoke_a)
	rd.free_rid(smoke_b)
	rd.free_rid(smoke_img)

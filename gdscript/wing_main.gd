extends Node
class_name WingMain

var c = WingConfig.new()
var s = WingState.new(c)
var wing_hud = WingHud.new(s, c)
var wing_gpu = WingGpu.new(s, c)

var ceiling: int = c.SUBSTEPS_MAX
var adaptative_substep := false
var ticks_count := 0
var frame := 0

func _ready() -> void:
	# Setup solid buffer
	wing_gpu.setup_solid_buffer()
	# Setup physics buffer
	wing_gpu.setup_physics_buffer()
	wing_gpu.apply_re(s.re_cur)
	# Setup fumee buffer
	wing_gpu.setup_smoke_buffer()
	# Setup shader
	s.disp = $Display
	wing_gpu.setup_shader()
	# Setup labels 
	add_child(s.info)
	add_child(s.info_fps)
	add_child(s.info_mode)
	add_child(s.info_instructions)
	wing_gpu.sample()

func _process(_delta: float) -> void:
	if adaptative_substep: adapt()
	wing_hud.update_info2()
	frame += 1
	if frame % c.SAMPLE_EVERY == 0 and s.step > int(c.T_RAMP):
		wing_gpu.sample()

func _physics_process(_delta: float):
	s.substeps_tick = s.substeps
	ticks_count += 1
	input_angle()
	wing_gpu.update_re()
	wing_gpu.compute_physics()

func input_angle():
	# Commande : flèches droite/gauche
	var dir := 0
	if Input.is_key_pressed(KEY_RIGHT): dir += 1
	if Input.is_key_pressed(KEY_LEFT): dir -= 1
	if dir != 0:
		s.alpha_deg = clampf(s.alpha_deg + dir * c.ALPHA_PER_STEP * s.substeps_tick, -20.0, 20.0)
		s.mask_dirty = true
		s.settle_until = s.step + c.SETTLE
		s.cd_sum = 0.0
		s.cl_sum = 0.0
		s.cd_n = 0

func adapt() -> void:
	var win_start := 0
	var frames_count := 0
	var ok_windows := 0
	if Time.get_ticks_msec() < 5000: return
	frames_count += 1
	var now := Time.get_ticks_msec()
	if win_start == 0:
		win_start = now
	var el := now - win_start
	if el < 1000:
		return
	var rate := ticks_count * 1000.0 / el
	var fps := frames_count * 1000.0 / el
	var overloaded = rate < 0.97 * Engine.physics_ticks_per_second or fps < c.MIN_FPS
	if overloaded:
		ceiling = maxi(s.substeps - 1, c.SUBSTEPS_MIN)
		s.substeps = maxi(c.SUBSTEPS_MIN, int(s.substeps * 0.85))
		ok_windows = 0
	else:
		ok_windows += 1
		if ok_windows % 3 == 0 and s.substeps < ceiling:
			s.substeps += 1
		if ok_windows % 20 == 0:
			ceiling = mini(ceiling + 1, c.SUBSTEPS_MAX)
	win_start = now
	ticks_count = 0
	frames_count = 0

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_V:
			s.disp_mode = (s.disp_mode + 1) % 5
			s.mat.set_shader_parameter("mode", s.disp_mode)
		elif event.keycode == KEY_UP:
			s.re_target = minf(s.re_target * 1.1, c.RE_MAX)
		elif event.keycode == KEY_DOWN:
			s.re_target = maxf(s.re_target / 1.1, c.RE_MIN)
		elif event.keycode == KEY_H:
			wing_hud.update_hud_visibility()

extends Node
class_name WingHud

var c: WingConfig
var s: WingState
var display_mode:Array[String] = ["u.y", "|u|", "rot(u)", "rho", "streamline"]

func _init(state: WingState, config: WingConfig) -> void:
	s = state
	c = config
	s.info = Label.new()
	s.info.position = Vector2(20, 20)
	setup_label(s.info)
	s.info_fps = Label.new()
	s.info_fps.position = Vector2(c.NX-80,20)
	setup_label(s.info_fps)
	s.info_mode = Label.new()
	s.info_mode.position = Vector2(20, c.NY-60)
	setup_label(s.info_mode)
	s.info_instructions = Label.new()
	s.info_instructions.position = Vector2(c.NX-290, c.NY-80)
	setup_label(s.info_instructions)

func setup_label(l:Label):
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)

func update_info2() -> void:
	var u_phys = s.re_cur * c.NU_AIR / c.C_PHYS        # m/s
	var dx = c.C_PHYS / c.C                            # m par maille
	var dt = c.U_IN * dx / u_phys                      # s par pas LBM
	var steps_s = float(s.substeps) * Engine.physics_ticks_per_second
	var slow = 1.0 / maxf(steps_s * dt, 1e-9)       # temps réel / temps simulé
	var delta = 5.0 * c.C / sqrt(s.re_cur)          # couche limite en bord de fuite (mailles)
	var cf = 0.664 / sqrt(0.5 * s.re_cur)           # Blasius à mi-corde
	var utau = c.U_IN * sqrt(0.5 * cf)
	var yplus = utau * 0.5 / s.nu_lat
	s.info_fps.text = "fps: %.1f" % Engine.get_frames_per_second()
	# Text and simulation info
	s.info.text = "Wing variables: alpha = %.2f deg   Cl = %.4f   Cd = %.4f\nmoyennes : Cl = %.4f   Cd = %.4f   %s\n\n" % [
		s.alpha_deg, s.cl, s.cd,
		s.cl_sum / maxi(s.cd_n, 1), s.cd_sum / maxi(s.cd_n, 1),
		"" if s.settled else "(transitoire)"]
	s.info.text += "Simulation variables: Re = %.0f   tau = %.4f   Ma = %.3f\nvent = %.3f m/s   ralenti x%.1f   t_phys = %.3f s\ndelta = %.1f mailles   y+ (Blasius) = %.2f" % [
		s.re_cur, s.tau, sqrt(3.0) * c.U_IN, u_phys, slow, s.step * dt, delta, yplus]
	# Mode info
	s.info_mode.text = "Mode: %s\n" % [display_mode[s.disp_mode]]
	for i in range(3):
		s.info_mode.text += "%s, " % [display_mode[(s.disp_mode+i+1)%5]]
	s.info_mode.text += display_mode[(s.disp_mode+4)%5]
	# Instruction info
	s.info_instructions.text = "Left/Right Arrow to change the angle\nUp/Down Arrow to change Re\nV to change view mode"

func update_hud_visibility():
	s.info.visible = !s.info.visible
	s.info_fps.visible = !s.info_fps.visible
	s.info_mode.visible = !s.info_mode.visible
	s.info_instructions.visible = !s.info_instructions.visible

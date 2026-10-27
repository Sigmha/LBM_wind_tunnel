extends Node
class_name WingState

var c:WingConfig

func _init(config: WingConfig) -> void:
	c = config

var re_cur := 500.0
var re_target := 500.0
var substeps := 35
var substeps_tick := 35
var nu_lat := 0.0
var tau: float
var step:int = 0
var alpha_deg := 5.0
var cl_sum := 0.0
var cd_sum := 0.0
var cd_n := 0
var cd: float = 0.0
var cl: float = 0.0
var settled: bool
var settle_until: int = c.SETTLE
var disp_mode := 4
var mask_dirty := true
var mat: ShaderMaterial
var disp: TextureRect
var info: Label
var info_fps: Label
var info_mode: Label
var info_instructions: Label

extends Area3D
class_name SmoothLUTChanger

@export var enable: bool = true
@export var player_body: CharacterBody3D = null
@export var LUT: ColorRect
@export var change_lut_speed: float = 1.0
@export var use_distance_to_marker3d: bool = false
@export var marker3d: Marker3D 
@export var max_distance: float = 1.0

var lut_shader: ShaderMaterial = null
var lut_changed: bool = false
var last_target_blend = 0.0

func _ready():
	connect("body_entered", Callable(self, "lut_change_area_entered"))
	connect("body_exited", Callable(self, "lut_change_area_exited"))
	set_collision_mask_value(4, true)
	lut_shader = LUT.material

func _process(delta: float):
	if not enable: return
	var target_blend: float = 0.0
	if lut_changed:
		if use_distance_to_marker3d:
			var dist_to_player = player_body.global_position.distance_to(marker3d.global_position)
			target_blend = clamp(1.0 - (dist_to_player / max_distance), 0.0, 1.0)
			last_target_blend = target_blend
		else: target_blend = 1.0 if lut_changed else 0.0
	else:
		target_blend = last_target_blend
	lut_shader.set_shader_parameter("blend_amount", move_toward(lut_shader.get_shader_parameter("blend_amount"), target_blend, change_lut_speed * delta))

func lut_change_area_entered(body):
	if enable: if body.is_in_group("Player"): lut_changed = true
func lut_change_area_exited(body):
	if enable: if body.is_in_group("Player"): lut_changed = false

@tool
extends StaticBody3D

enum HandState { IDLE }

@export var powered: bool = true:
	set(value):
		powered = value
		if is_node_ready():
			set_power()

@export var jump_height: float = 3.0
@export var max_distance: float = 4.0

@onready var detection_area: Area3D = $DetectionArea
@onready var sm_jump_pad: MeshInstance3D = $mesh_purple_pad/SM_Jump_Pad
@onready var light: OmniLight3D = $OmniLight3D
@onready var jump: AudioStreamPlayer3D = $SwRocketHandJump

const M_JUMP_PAD_HAND_ICO = preload("uid://c6ctoofi7ttr1")

var is_on_cooldown: bool = false
var cooldown_time: float = 0.7

func _ready() -> void:
	set_power()
	
	if not Engine.is_editor_hint():
		if detection_area:
			detection_area.area_entered.connect(_initiate_jump)

func set_power() -> void:
	if not sm_jump_pad or not light:
		return
		
	var base_mat: Material = sm_jump_pad.get_active_material(0)
	if base_mat:
		var unique_mat: Material = base_mat.duplicate()
		unique_mat.next_pass = M_JUMP_PAD_HAND_ICO if powered else null
		sm_jump_pad.set_surface_override_material(0, unique_mat)
		
	light.light_energy = 1.0 if powered else 0.0

func _initiate_jump(area: Area3D) -> void:
	if not powered or is_on_cooldown:
		return

	if area.name == "JumpArea":
		if Manager.right_hand.current_state != HandState.IDLE:
			jump.play()
			var player = Manager.player
			if not player:
				return
			var relative_height: float = player.global_position.y - global_position.y
			if relative_height >= jump_height:
				return
			var pad_xz = Vector2(global_position.x, global_position.z)
			var player_xz = Vector2(player.global_position.x, player.global_position.z)
			var distance: float = pad_xz.distance_to(player_xz)
			var falloff: float = clamp(1.0 - (distance / max_distance), 0.0, 1.0)
			if falloff <= 0.0:
				return
			var final_jump_height: float = jump_height * falloff
			is_on_cooldown = true
			var launch_dir: Vector3 = global_transform.basis.y
			player.apply_directional_jump(launch_dir, final_jump_height)
			await get_tree().create_timer(cooldown_time).timeout
			is_on_cooldown = false

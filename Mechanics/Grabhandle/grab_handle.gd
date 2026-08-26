@tool
extends StaticBody3D

enum SwingType {
	Pull,
	Swing
}

const GRAB_HANDLE_NORMAL = preload("uid://ll6ylwf40r71")
const GRAB_HANDLE_OUTLINE = preload("uid://clgvts7tnf54t")

@onready var grab_target: Area3D = $GrabTarget
@onready var pull_mark: Marker3D = $PullMark
@onready var sm_grap_handle_mo: MeshInstance3D = $SM_GrapHandle/SM_GrapHandle_mo

@export var swing_type: SwingType

# Using a setter updates the material immediately when toggled in the Inspector
@export var outline: bool = false:
	set(value):
		outline = value
		_update_material()

@export_category("Pull Dynamics")
@export var spring_strength: float = 8.0
@export var damping_factor: float = 6.3
@export var stop_distance: float = 0.0
@export var max_speed_limit: float = 15.0 # The anti-catapult brake

var is_pulling: bool = false
var current_pull_velocity: Vector3 = Vector3.ZERO 

func _ready() -> void:
	_update_material()
	
	# Prevent gameplay logic from executing inside the editor
	if Engine.is_editor_hint():
		return
		
	if grab_target:
		grab_target.swing_type = swing_type

func _process(_delta: float) -> void:
	# Keep material synced during editor playback / runtime
	if Engine.is_editor_hint():
		_update_material()

func _physics_process(delta: float) -> void:
	# Stop physics & player logic from running inside the Editor
	if Engine.is_editor_hint():
		return
	
	grab_target.is_swingable = (swing_type == SwingType.Swing)
	
	if swing_type == SwingType.Pull and grab_target.allow_pulling:
		if is_pulling:
			var to_target = pull_mark.global_position - Manager.player.global_position
			var dist = to_target.length()
			
			if dist > stop_distance:
				# Zero out internal player velocities so they don't fight the pull
				Manager.player.walk_vel = Vector3.ZERO
				Manager.player.grav_vel = Vector3.ZERO
				Manager.player.jump_vel = Vector3.ZERO
				
				var direction = to_target.normalized()
				var spring_force = direction * (spring_strength * dist)
				var damping_force = -current_pull_velocity * damping_factor
				
				current_pull_velocity += (spring_force + damping_force) * delta
				
				# PREVENT CATAPULT: Cap the maximum speed the spring can generate
				current_pull_velocity = current_pull_velocity.limit_length(max_speed_limit)
				
				Manager.player.external_velocity = current_pull_velocity
			else:
				# Hold position steadily without retracting
				current_pull_velocity = Vector3.ZERO
				Manager.player.external_velocity = Vector3.ZERO
		else:
			current_pull_velocity = Vector3.ZERO

func _update_material() -> void:
	if sm_grap_handle_mo:
		var mat = GRAB_HANDLE_OUTLINE if outline else GRAB_HANDLE_NORMAL
		sm_grap_handle_mo.set_surface_override_material(0, mat)

func _on_grab_target_on_pulled(_hand_side: String) -> void:
	is_pulling = true
	current_pull_velocity = Vector3.ZERO 

func _on_grab_target_on_released(_hand_side: String) -> void:
	is_pulling = false
	current_pull_velocity = Vector3.ZERO

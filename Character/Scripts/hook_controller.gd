class_name HookController
extends Node

@export_category("Hook Controller")
@export_group("Required Settings")
@export var hook_raycast: RayCast3D
@export var player_body: CharacterBody3D

@export_group("Optional Settings")
var swing_force: float = 3.0  # Strength of initial movement
var gravity_scale: float = 0.5  # Multiplier for gravity while swinging
var damping: float = 0.999  # Reduces infinite swinging over time

var is_hook_launched: bool = false
var hook_target_pos: Vector3 = Vector3.ZERO
var rope_length: float = 0.0
var swing_velocity: Vector3 = Vector3.ZERO

func _physics_process(delta: float) -> void:
	if not is_hook_launched:
		return
	if player_body.is_on_floor():
		return
	_handle_swinging(delta)

func _launch_hook(pos: Vector3) -> void:
	is_hook_launched = true
	hook_target_pos = pos

	# Set rope length to match initial distance
	rope_length = (hook_target_pos - player_body.global_position).length()
	rope_length -= 0.07
	# Preserve lateral velocity while hooking, ensuring smoother initial swing
	var to_hook = (hook_target_pos - player_body.global_position).normalized()
	swing_velocity = player_body.velocity - to_hook * player_body.velocity.dot(to_hook)

	# Apply initial swing force based on distance to target and rope length
	var time_factor = clamp(rope_length / 10, 1.0, 3.0)  # Adjust this factor as needed
	var initial_swing = to_hook * swing_force * time_factor
	swing_velocity += initial_swing

func _retract_hook() -> void:
	is_hook_launched = false

func _handle_swinging(delta: float) -> void:
	var to_hook = hook_target_pos - player_body.global_position
	var current_distance = to_hook.length()

	# Ensure player stays at rope length (prevents weird orbiting)
	if current_distance > rope_length:
		var pull_direction = to_hook.normalized()
		var correction = pull_direction * (current_distance - rope_length)
		player_body.global_position += correction

	# Apply gravity for natural swinging
	var gravity = Vector3.DOWN * gravity_scale * delta * 60
	swing_velocity += gravity

	# Calculate tangential velocity (real swinging motion)
	var radial_velocity = to_hook.normalized().dot(swing_velocity)
	var tangential_velocity = swing_velocity - to_hook.normalized() * radial_velocity

	# Reduce velocity over time (prevents infinite swinging)
	swing_velocity = tangential_velocity * damping

	# Apply final velocity to player
	if swing_velocity.length() < 0.1:
		swing_velocity = Vector3.ZERO

	player_body.velocity = swing_velocity
	
	if radial_velocity > 1.0:
		pass

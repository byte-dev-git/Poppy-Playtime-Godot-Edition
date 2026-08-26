extends RigidBody3D
class_name PullableObject

@export var pull_force: float = 35.0
@export var max_speed: float = 10.0 
@export var two_hand_bonus_multiplier: float = 1.4 
@export var vertical_lift_factor: float = 0.15 

var active_pullers: Dictionary = {}

signal on_grabbed
signal on_pulled
signal on_released

func trigger_grab() -> void:
	on_grabbed.emit()

func start_pulling(hand_id: String, pull_target_pos: Vector3) -> void:
	var was_empty = active_pullers.is_empty()
	active_pullers[hand_id] = pull_target_pos
	
	if was_empty:
		on_pulled.emit()

func stop_pulling(hand_id: String) -> void:
	if active_pullers.has(hand_id):
		active_pullers.erase(hand_id)
		if active_pullers.is_empty():
			on_released.emit()

func update_pull_target(hand_id: String, pull_target_pos: Vector3) -> void:
	if active_pullers.has(hand_id):
		active_pullers[hand_id] = pull_target_pos

func _physics_process(_delta: float) -> void:
	var pull_count = active_pullers.size()
	if pull_count == 0:
		return

	var combined_target := Vector3.ZERO
	for hand_id in active_pullers:
		combined_target += active_pullers[hand_id]
	var avg_target_pos = combined_target / float(pull_count)

	var to_target = avg_target_pos - global_position
	if to_target.length() < 0.3:
		return

	var pull_dir = to_target.normalized()
	pull_dir.y *= vertical_lift_factor
	pull_dir = pull_dir.normalized()

	var current_force = pull_force
	if pull_count > 1:
		current_force *= two_hand_bonus_multiplier

	apply_central_force(pull_dir * current_force * mass)

	if linear_velocity.length() > max_speed:
		linear_velocity = linear_velocity.normalized() * max_speed

extends Node
class_name CableManager

@export var max_cable_length: float = 30.0
@export var cables: Array[CablePhysics] = []
@export var cable_progress_bar: TextureProgressBar

var is_cable_powered: bool = false

func set_power(on: bool) -> void:
	for cable in cables:
		if cable:
			cable.set_powered(on)
	is_cable_powered = on

func _physics_process(_delta: float) -> void:
	var total_length = get_total_cable_length()
	_update_progress_ui(total_length)
	
	if total_length >= max_cable_length:
		for cable in cables:
			if cable != null and cable.is_active and cable.launch_hand:
				if cable.launch_hand.current_state == cable.launch_hand.HandState.LAUNCHING:
					cable.launch_hand.start_retract()

func apply_player_tension(player: CharacterBody3D) -> void:
	for cable in cables:
		if cable != null and cable.is_active and cable.launch_hand:
			if cable.launch_hand.current_state == cable.launch_hand.HandState.ATTACHED:
				cable.apply_shared_tension(player)

func _update_progress_ui(total_length: float) -> void:
	if cable_progress_bar == null or max_cable_length <= 0.0:
		return
	var remaining_ratio: float = 1.0 - clamp(total_length / max_cable_length, 0.0, 1.0)
	cable_progress_bar.value = remaining_ratio * 100.0

func get_total_cable_length() -> float:
	var total: float = 0.0
	for cable in cables:
		if cable != null and cable.is_active and cable.launch_hand:
			var state = cable.launch_hand.current_state
			if state in [cable.launch_hand.HandState.LAUNCHING, cable.launch_hand.HandState.ATTACHED, cable.launch_hand.HandState.PULLING]:
				total += cable.get_cable_length()
	return total

func get_remaining_length_for(requesting_cable: CablePhysics) -> float:
	var used_by_others: float = 0.0
	for cable in cables:
		if cable != null and cable != requesting_cable and cable.is_active and cable.launch_hand:
			var state = cable.launch_hand.current_state
			if state in [cable.launch_hand.HandState.LAUNCHING, cable.launch_hand.HandState.ATTACHED, cable.launch_hand.HandState.PULLING]:
				used_by_others += cable.get_cable_length()
	return max(0.0, max_cable_length - used_by_others)

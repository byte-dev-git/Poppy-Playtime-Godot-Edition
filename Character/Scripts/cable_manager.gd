extends Node
class_name CableManager

@export var cables: Array[CablePhysics] = []
@export var cable_progress_bar: TextureProgressBar

var is_cable_powered: bool = false
var current_power_color: Color = Color.WHITE

var active_sources: Array[Object] = []
var active_source_colors: Dictionary = {}

var max_cable_length: float = 30.0

func set_power(on: bool, color: Color = Color.WHITE, source: Object = null) -> void:
	if source == null:
		_apply_power_state(on, color)
		return

	if on:
		if not active_sources.has(source):
			active_sources.append(source)
		active_source_colors[source] = color
	else:
		active_sources.erase(source)
		active_source_colors.erase(source)

	if active_sources.size() > 0:
		var primary_source = active_sources[0]
		var primary_color: Color = active_source_colors.get(primary_source, Color.WHITE)
		_apply_power_state(true, primary_color)
	else:
		_apply_power_state(false, Color.WHITE)

func _apply_power_state(on: bool, color: Color) -> void:
	is_cable_powered = on
	current_power_color = color
	for cable in cables:
		if cable:
			cable.set_powered(on, color)

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

# Helper to ensure RETRACTING cables are factored into calculations
func _is_cable_active_state(launch_hand: Object) -> bool:
	if launch_hand == null:
		return false
	var state = launch_hand.current_state
	return state in [
		launch_hand.HandState.LAUNCHING, 
		launch_hand.HandState.ATTACHED, 
		launch_hand.HandState.PULLING,
		launch_hand.HandState.RETRACTING
	]

func get_total_cable_length() -> float:
	var total: float = 0.0
	for cable in cables:
		if cable != null and cable.is_active and cable.launch_hand:
			if _is_cable_active_state(cable.launch_hand):
				total += cable.get_cable_length()
	return total

func get_remaining_length_for(requesting_cable: CablePhysics) -> float:
	var used_by_others: float = 0.0
	for cable in cables:
		if cable != null and cable != requesting_cable and cable.is_active and cable.launch_hand:
			if _is_cable_active_state(cable.launch_hand):
				used_by_others += cable.get_cable_length()
	return max(0.0, max_cable_length - used_by_others)

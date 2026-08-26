extends StaticBody3D


@onready var omni_light: OmniLight3D = $OmniLight3D

var is_on: bool = false

func _process(delta: float) -> void:
	omni_light.light_energy = 0.125 if is_on else 0.0
	Manager.cable_manager.set_power(true if is_on else false)

func _on_grab_target_on_grabbed(_hand_side: String) -> void:
	is_on = true

func _on_grab_target_on_released(_hand_side: String) -> void:
	is_on = false

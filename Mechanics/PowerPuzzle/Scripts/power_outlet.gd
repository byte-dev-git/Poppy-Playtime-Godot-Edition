@tool
extends StaticBody3D

enum ColorPreset { CYAN, RED, GREEN, PURPLE, YELLOW }
const PRESET_VALUES = {
	ColorPreset.CYAN: Color(0, 1, 1),
	ColorPreset.RED: Color(1, 0, 0),
	ColorPreset.GREEN: Color(0, 1, 0),
	ColorPreset.PURPLE: Color(0.983, 0.0, 1.0, 1.0),
	ColorPreset.YELLOW: Color(1, 1, 0)
}

@export var color_preset: ColorPreset = ColorPreset.CYAN:
	set(value):
		color_preset = value
		_update_visuals()

@onready var omni_light: OmniLight3D = $OmniLight3D
@onready var mesh: MeshInstance3D = $SM_PowerSource_A_mo_004

var is_on: bool = false
var current_color: Color = Color.WHITE
var dynamic_material: StandardMaterial3D = null

func _ready() -> void:
	if mesh:
		var mat = mesh.get_surface_override_material(6)
		if mat:
			dynamic_material = mat.duplicate()
			mesh.set_surface_override_material(6, dynamic_material)
	_update_visuals()

func _update_visuals() -> void:
	current_color = PRESET_VALUES[color_preset]
	if omni_light:
		omni_light.light_color = current_color
	if dynamic_material:
		dynamic_material.albedo_color = current_color
		dynamic_material.emission = current_color

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		if omni_light:
			omni_light.light_energy = 0.125
	else:
		if omni_light:
			omni_light.light_energy = 0.125 if is_on else 0.0

func _on_grab_target_on_grabbed(_hand_side: String) -> void:
	is_on = true
	if Manager and Manager.cable_manager:
		Manager.cable_manager.set_power(true, current_color, self)

func _on_grab_target_on_released(_hand_side: String) -> void:
	is_on = false
	if Manager and Manager.cable_manager:
		Manager.cable_manager.set_power(false, current_color, self)

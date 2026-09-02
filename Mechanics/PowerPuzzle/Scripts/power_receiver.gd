@tool
extends StaticBody3D

signal powered

enum ColorPreset { CYAN, RED, GREEN, PURPLE, YELLOW }
const PRESET_VALUES = {
	ColorPreset.CYAN: Color(0, 1, 1),
	ColorPreset.RED: Color(1, 0, 0),
	ColorPreset.GREEN: Color(0, 1, 0),
	ColorPreset.PURPLE: Color(0.983, 0.0, 1.0, 1.0),
	ColorPreset.YELLOW: Color(1, 1, 0)
}

@export var accepted_color_preset: ColorPreset = ColorPreset.CYAN:
	set(value):
		accepted_color_preset = value
		_update_visuals()
		_update_poles_color()

var accepted_color: Color = Color.WHITE

@export var bolt_spacing: float = 0.15:
	set(value):
		bolt_spacing = value
		_update_bolts()

@export var power_poles: Array[StaticBody3D] = []:
	set(value):
		if value.size() > 4:
			value.resize(4)
		power_poles = value
		_update_bolts()
		_update_poles_color()

@export var is_fully_powered: bool = false:
	set(value):
		if value and not colors_locked:
			_lock_colors()
		is_fully_powered = value
		_update_bolt_states()

@onready var grab_coiling: AudioStreamPlayer = $SwConduitHandGrabCoiling
@onready var omni_light: OmniLight3D = $OmniLight3D
@onready var grab_target: Area3D = $GrabTarget
@onready var base_bolt: MeshInstance3D = $Bolt
@onready var mesh: MeshInstance3D = $PowerSource/SM_Power_Receiver_A_mo_003

var generated_bolts: Array[MeshInstance3D] = []
var poles_powered: bool = false
var dynamic_mesh_mat: StandardMaterial3D = null

var locked_bolt_colors: Array[Color] = []
var locked_main_color: Color = Color.WHITE
var colors_locked: bool = false

const SW_CONDUIT_HAND_GRAB_COILING = preload("uid://c4vkj6dn53lva")

func _ready() -> void:
	if mesh:
		var mat = mesh.get_surface_override_material(2)
		if mat:
			dynamic_mesh_mat = mat.duplicate()
			mesh.set_surface_override_material(2, dynamic_mesh_mat)
			
	if not Engine.is_editor_hint():
		if omni_light:
			omni_light.visible = false
			
	_update_visuals()
	_update_bolts()
	_update_poles_color()

func _update_visuals() -> void:
	accepted_color = PRESET_VALUES[accepted_color_preset]
	if dynamic_mesh_mat:
		dynamic_mesh_mat.albedo_color = accepted_color
		dynamic_mesh_mat.emission = accepted_color
	if Engine.is_editor_hint() and omni_light:
		omni_light.light_color = accepted_color

func _update_poles_color() -> void:
	for pole in power_poles:
		if pole != null and is_instance_valid(pole) and pole.has_method("set_expected_color"):
			pole.set_expected_color(PRESET_VALUES[accepted_color_preset])

func _process(_delta: float) -> void:
	_update_bolt_states()
	
	if Engine.is_editor_hint():
		return

	var all_currently_powered: bool = power_poles.size() > 0
	for pole in power_poles:
		if pole == null or not is_instance_valid(pole):
			all_currently_powered = false
			break
		if "is_powered" in pole and not pole.is_powered:
			all_currently_powered = false
			break
			
		if "active_power_color" in pole:
			if pole.active_power_color != accepted_color:
				all_currently_powered = false
				break

	poles_powered = all_currently_powered

	if grab_target:
		if poles_powered:
			grab_target.custom_grab_sound = SW_CONDUIT_HAND_GRAB_COILING
		else:
			grab_target.custom_grab_sound = null

func _lock_colors() -> void:
	locked_bolt_colors.clear()
	var last_valid_color: Color = Color.WHITE
	
	for pole in power_poles:
		var c = Color.WHITE
		if pole != null and is_instance_valid(pole) and "active_power_color" in pole:
			c = pole.active_power_color
		locked_bolt_colors.append(c)
		last_valid_color = c
		
	locked_main_color = last_valid_color
	colors_locked = true

func _update_bolts() -> void:
	if base_bolt == null:
		return

	base_bolt.visible = false 
	generated_bolts = generated_bolts.filter(func(b): return is_instance_valid(b))
	var count: int = mini(power_poles.size(), 4)

	while generated_bolts.size() < count:
		var new_bolt: MeshInstance3D = base_bolt.duplicate() as MeshInstance3D
		new_bolt.visible = true
		add_child(new_bolt)
		_make_material_unique(new_bolt)
		generated_bolts.append(new_bolt)

	while generated_bolts.size() > count:
		var extra_bolt = generated_bolts.pop_back()
		if is_instance_valid(extra_bolt):
			extra_bolt.queue_free()

	for i in range(count):
		var bolt = generated_bolts[i]
		if not is_instance_valid(bolt):
			continue
		var offset_x = (i - (count - 1) / 2.0) * bolt_spacing
		bolt.position = base_bolt.position + Vector3(offset_x, 0, 0)

func _update_bolt_states() -> void:
	var count: int = mini(power_poles.size(), generated_bolts.size())
	var last_active_color: Color = Color.WHITE
	
	for i in range(count):
		var bolt = generated_bolts[i]
		var pole = power_poles[i]
		
		if not is_instance_valid(bolt): continue

		var is_on: bool = false
		var current_color: Color = Color.WHITE
		
		if is_fully_powered:
			is_on = true
			if colors_locked and i < locked_bolt_colors.size():
				current_color = locked_bolt_colors[i]
		elif pole != null and is_instance_valid(pole) and "is_powered" in pole:
			is_on = pole.is_powered
			if is_on and "active_power_color" in pole:
				current_color = pole.active_power_color

		if is_on: last_active_color = current_color
		_toggle_emission(bolt, is_on, current_color)
		
	if omni_light and is_fully_powered:
		omni_light.light_color = locked_main_color if colors_locked else last_active_color

func _make_material_unique(bolt: MeshInstance3D) -> void:
	var mat: Material = bolt.material_override
	if mat:
		bolt.material_override = mat.duplicate()
	else:
		mat = bolt.get_surface_override_material(0)
		if mat:
			bolt.set_surface_override_material(0, mat.duplicate())

func _toggle_emission(bolt: MeshInstance3D, enabled: bool, color: Color = Color.WHITE) -> void:
	var mat: Material = bolt.material_override
	if mat == null: mat = bolt.get_surface_override_material(0)

	if mat is StandardMaterial3D or mat is ORMMaterial3D:
		mat.emission_enabled = enabled
		if enabled:
			mat.albedo_color = color
			mat.emission = color

func _on_grab_target_on_grabbed(_hand_side: String) -> void:
	if Engine.is_editor_hint(): return
	
	if poles_powered:
		is_fully_powered = true
		
		if _hand_side.to_lower() == "right": Manager.left_hand.start_retract()
		elif _hand_side.to_lower() == "left": Manager.right_hand.start_retract()
			
		grab_target.use_custom_grab_sound = true
		if omni_light: omni_light.visible = true
		powered.emit()
		
		await get_tree().create_timer(0.1).timeout
		grab_target.is_disabled = true

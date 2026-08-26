@tool
extends StaticBody3D

signal powered

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

@export var is_fully_powered: bool = false:
	set(value):
		is_fully_powered = value
		_update_bolt_states()

@onready var grab_coiling: AudioStreamPlayer = $SwConduitHandGrabCoiling
@onready var omni_light: OmniLight3D = $OmniLight3D
@onready var grab_target: Area3D = $GrabTarget
@onready var base_bolt: MeshInstance3D = $Bolt

var generated_bolts: Array[MeshInstance3D] = []
var poles_powered: bool = false

const SW_CONDUIT_HAND_GRAB_COILING = preload("uid://c4vkj6dn53lva")

func _ready() -> void:
	if not Engine.is_editor_hint():
		if omni_light:
			omni_light.visible = false
	_update_bolts()

func _process(_delta: float) -> void:
	_update_bolt_states()

	if Engine.is_editor_hint():
		return

	# Dynamically verify if all connected poles are active
	var all_currently_powered: bool = power_poles.size() > 0
	for pole in power_poles:
		if pole == null or not is_instance_valid(pole):
			all_currently_powered = false
			break
		if "is_powered" in pole and not pole.is_powered:
			all_currently_powered = false
			break

	poles_powered = all_currently_powered

	# Set custom grab sound while all poles are powered
	if grab_target:
		if poles_powered:
			grab_target.custom_grab_sound = SW_CONDUIT_HAND_GRAB_COILING
		else:
			grab_target.custom_grab_sound = null

func _update_bolts() -> void:
	if base_bolt == null:
		return

	base_bolt.visible = false # Template bolt reference

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
	
	for i in range(count):
		var bolt = generated_bolts[i]
		var pole = power_poles[i]
		
		if not is_instance_valid(bolt):
			continue

		var is_on: bool = false
		
		# Lock emissions ON permanently only after grabbing while fully powered
		if is_fully_powered:
			is_on = true
		elif pole != null and is_instance_valid(pole) and "is_powered" in pole:
			is_on = pole.is_powered

		_toggle_emission(bolt, is_on)

func _make_material_unique(bolt: MeshInstance3D) -> void:
	var mat: Material = bolt.material_override
	if mat:
		bolt.material_override = mat.duplicate()
	else:
		mat = bolt.get_surface_override_material(0)
		if mat:
			bolt.set_surface_override_material(0, mat.duplicate())

func _toggle_emission(bolt: MeshInstance3D, enabled: bool) -> void:
	var mat: Material = bolt.material_override
	if mat == null:
		mat = bolt.get_surface_override_material(0)

	if mat is StandardMaterial3D or mat is ORMMaterial3D:
		mat.emission_enabled = enabled

func _on_grab_target_on_grabbed(_hand_side: String) -> void:
	if Engine.is_editor_hint():
		return
	if poles_powered:
		is_fully_powered = true
		
		if _hand_side.to_lower() == "right":
			Manager.left_hand.start_retract()
		elif _hand_side.to_lower() == "left":
			Manager.right_hand.start_retract()
			
		grab_target.use_custom_grab_sound = true
		if omni_light:
			omni_light.visible = true
			
		powered.emit()
		
		await get_tree().create_timer(0.1)
		grab_target.is_disabled = true

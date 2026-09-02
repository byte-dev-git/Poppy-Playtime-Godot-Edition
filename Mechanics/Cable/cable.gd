extends Node
class_name Cable

@export_group("Power State")
@export var powered: bool = false
@export var cable_fill_speed: float = 1.0

@export_group("Cable Mesh & Shader")
@export var cable_mesh_node: MeshInstance3D
@export var cable_length: float = 1.0
@export var cable_fill_direction: bool = false

@export_group("Puzzle Event Wiring")
@export var puzzle: Node
@export var powerable_on: bool = true
@export var power_on_signal: String = ""
@export var powerable_off: bool = true
@export var power_off_signal: String = ""
@export var toggle: bool = false
@export var toggle_signal: String = ""

signal cable_powered
signal cable_off

var material: ShaderMaterial = null
var uses_signals: bool = false
var do_once_powered: bool = false
var do_once_off: bool = false

const FILL_MIN: float = 0.0
const FILL_MAX: float = 1.2

const CABLE_POWER_RES: ShaderMaterial = preload("uid://bjce75r1m6ypo")

func _ready() -> void:
	if not cable_mesh_node:
		push_error("CablePower: No cable_mesh_node assigned!")
		return

	# Duplicate material instance so state changes only affect this specific cable
	if CABLE_POWER_RES:
		material = CABLE_POWER_RES.duplicate() as ShaderMaterial
	else:
		var current_mat = cable_mesh_node.get_active_material(0)
		if current_mat:
			material = current_mat.duplicate() as ShaderMaterial

	if material:
		cable_mesh_node.set_surface_override_material(0, material)
		material.set_shader_parameter("invert_direction", cable_fill_direction)
		material.set_shader_parameter("cable_length", cable_length)
		material.set_shader_parameter("fill_amount", FILL_MAX if powered else FILL_MIN)

	# Connect Godot 4 puzzle signals safely
	if puzzle:
		if powerable_on and not power_on_signal.is_empty() and puzzle.has_signal(power_on_signal):
			puzzle.connect(power_on_signal, power_on)
		if powerable_off and not power_off_signal.is_empty() and puzzle.has_signal(power_off_signal):
			puzzle.connect(power_off_signal, power_off)
		if toggle and not toggle_signal.is_empty() and puzzle.has_signal(toggle_signal):
			puzzle.connect(toggle_signal, toggle_power)

	if powered:
		power_on()
	else:
		power_off()

	uses_signals = true

func _process(delta: float) -> void:
	if not material:
		return

	var current_fill: float = material.get_shader_parameter("fill_amount")

	if powered:
		var new_fill: float = move_toward(current_fill, FILL_MAX, cable_fill_speed * delta)
		material.set_shader_parameter("fill_amount", new_fill)
		
		if new_fill >= 1.2 and do_once_powered and uses_signals:
			cable_powered.emit()
			do_once_powered = false
	else:
		var new_fill: float = move_toward(current_fill, FILL_MIN, cable_fill_speed * delta)
		material.set_shader_parameter("fill_amount", new_fill)
		
		if new_fill <= 0.0 and do_once_off and uses_signals:
			cable_off.emit()
			do_once_off = false

func toggle_power() -> void:
	if powered:
		power_off()
	else:
		power_on()

func power_on() -> void:
	powered = true
	do_once_powered = true
	do_once_off = false

func power_off() -> void:
	powered = false
	do_once_off = true
	do_once_powered = false

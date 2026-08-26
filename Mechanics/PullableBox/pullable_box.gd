@tool
extends PullableObject

enum BoxSize {
	SIZE_2X2M, 
	SIZE_4X2M,
	SIZE_75X75CM,
	SIZE_150X150CM
}

const PRESETS: Dictionary = {
	BoxSize.SIZE_75X75CM:  {"mass": 50.0,  "pull_force": 25.0, "max_speed": 12.0},
	BoxSize.SIZE_150X150CM: {"mass": 150.0, "pull_force": 20.0, "max_speed": 10.0},
	BoxSize.SIZE_2X2M:      {"mass": 350.0, "pull_force": 12.0, "max_speed": 8.0},
	BoxSize.SIZE_4X2M:      {"mass": 450.0, "pull_force": 10.0, "max_speed": 6.0}
}

@export var box_size: BoxSize = BoxSize.SIZE_2X2M:
	set(value):
		box_size = value
		_update_box_size()
		_apply_physics_preset()

@export var color: Color = Color(1.0, 0.0, 0.0, 1.0):
	set(value):
		color = value
		_update_color()

@onready var BoxSize_2x2M: MeshInstance3D = $SM_GrabBoxes_2x2M/Mesh
@onready var BoxSize_4x2M: MeshInstance3D = $SM_GrabBoxes_4x2M/Mesh
@onready var BoxSize_75x75CM: MeshInstance3D = $SM_GrabBoxes_75x75CM/Mesh
@onready var BoxSize_150x150CM: MeshInstance3D = $SM_GrabBoxes_150x150CM/Mesh

@onready var _2x_2m: CollisionShape3D = $"2x2M"
@onready var _4x_2m: CollisionShape3D = $"4x2M"
@onready var _75x_75cm: CollisionShape3D = $"75x75CM"
@onready var _150x_150cm: CollisionShape3D = $"150x150CM"

func _ready() -> void:
	_update_box_size()
	_update_color()
	_apply_physics_preset()

func _apply_physics_preset() -> void:
	if not PRESETS.has(box_size):
		return
		
	var preset: Dictionary = PRESETS[box_size]
	
	# Assign RigidBody3D mass if available
	if "mass" in self:
		set("mass", preset["mass"])
		
	# Assign inherited PullableObject properties
	if "pull_force" in self:
		set("pull_force", preset["pull_force"])
	if "max_speed" in self:
		set("max_speed", preset["max_speed"])

	notify_property_list_changed()

func _update_box_size() -> void:
	if not is_node_ready():
		return

	var meshes = [BoxSize_2x2M, BoxSize_4x2M, BoxSize_75x75CM, BoxSize_150x150CM]
	var collisions = [_2x_2m, _4x_2m, _75x_75cm, _150x_150cm]

	for i in range(meshes.size()):
		var is_active = (i == box_size)
		
		if meshes[i]:
			meshes[i].visible = is_active
			if meshes[i].get_parent():
				meshes[i].get_parent().visible = is_active
				
		if collisions[i]:
			collisions[i].disabled = not is_active

func _update_color() -> void:
	if not is_node_ready():
		return

	var meshes = [BoxSize_2x2M, BoxSize_4x2M, BoxSize_75x75CM, BoxSize_150x150CM]

	for mesh_inst in meshes:
		if not mesh_inst or not mesh_inst.mesh:
			continue

		var surface_idx = 1 if mesh_inst.mesh.get_surface_count() > 1 else 0

		if not mesh_inst.mesh.is_local_to_scene():
			mesh_inst.mesh = mesh_inst.mesh.duplicate()

		var mat = mesh_inst.mesh.surface_get_material(surface_idx)
		if mat:
			mat = mat.duplicate()
			mesh_inst.mesh.surface_set_material(surface_idx, mat)
			
			if mat is BaseMaterial3D:
				mat.albedo_color = color

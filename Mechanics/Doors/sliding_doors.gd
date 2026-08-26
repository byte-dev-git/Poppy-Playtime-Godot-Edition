@tool
extends Node3D



enum DoorSize { BIG, SMALL }

@export var door_size: DoorSize = DoorSize.BIG:
	set(value):
		door_size = value
		_update_door_variant()

@export var color: Color = Color.WHITE:
	set(value):
		color = value
		_update_surface_materials()

@export var enable_back_frame: bool = true:
	set(value):
		enable_back_frame = value
		_update_back_frames()

@onready var animation_tree: AnimationTree = $AnimationTree
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var close: AudioStreamPlayer3D = $SwMetalSlidingGateClose01
@onready var open: AudioStreamPlayer3D = $SwMetalSlidingGateOpen01

func _ready() -> void:
	_update_door_variant()
	_update_surface_materials()
	_update_back_frames()
	
	if not Engine.is_editor_hint():
		_set_animation_tree_active(false)
		if animation_player and not animation_player.animation_finished.is_connected(_on_animation_finished):
			animation_player.animation_finished.connect(_on_animation_finished)

func _update_door_variant() -> void:
	var door_a = get_node_or_null("DoorA")
	var door_b = get_node_or_null("DoorB")
	var is_big = (door_size == DoorSize.BIG)
	
	if door_a:
		door_a.visible = is_big
		_set_collisions_enabled(door_a, is_big)
		
	if door_b:
		door_b.visible = not is_big
		_set_collisions_enabled(door_b, not is_big)

func _set_collisions_enabled(parent: Node, enabled: bool) -> void:
	var collision_shapes = parent.find_children("*", "CollisionShape3D", true, false)
	for shape in collision_shapes:
		if shape is CollisionShape3D:
			shape.disabled = not enabled

func _update_surface_materials() -> void:
	var meshes = find_children("*", "MeshInstance3D", true, false)
	for mesh_node in meshes:
		if not mesh_node is MeshInstance3D or not mesh_node.mesh:
			continue
		
		var target_surface: int = -1
		match mesh_node.name:
			"Frame", "Frame_back":
				target_surface = 0
			"MainDoor", "DoorMain":
				target_surface = 1
		
		if target_surface != -1 and mesh_node.mesh.get_surface_count() > target_surface:
			_apply_unique_surface_color(mesh_node, target_surface, color)

func _apply_unique_surface_color(mesh_node: MeshInstance3D, surface_idx: int, color: Color) -> void:
	var existing_mat: Material = mesh_node.get_surface_override_material(surface_idx)
	if not existing_mat:
		existing_mat = mesh_node.mesh.surface_get_material(surface_idx)
	
	var unique_mat: ORMMaterial3D
	
	if existing_mat is ORMMaterial3D:
		unique_mat = existing_mat.duplicate() as ORMMaterial3D
	else:
		unique_mat = ORMMaterial3D.new()
	
	unique_mat.albedo_color = color
	mesh_node.set_surface_override_material(surface_idx, unique_mat)

func _update_back_frames() -> void:
	var back_frames = [
		get_node_or_null("DoorA/Frame/Frame_back"),
		get_node_or_null("DoorB/Frame/Frame_back")
	]
	for frame in back_frames:
		if frame:
			frame.visible = enable_back_frame

func open_door() -> void:
	_set_animation_tree_active(true)
	animation_tree.set("parameters/Transition/transition_request", "Open")
	open.play()

func close_door() -> void:
	_set_animation_tree_active(true)
	animation_tree.set("parameters/Transition/transition_request", "Close")
	close.play()

func _on_animation_finished(_anim_name: StringName) -> void:
	_set_animation_tree_active(false)

func _set_animation_tree_active(state: bool) -> void:
	if animation_tree:
		animation_tree.active = state

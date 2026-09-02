@tool
extends Area3D
class_name Interaction

@export var enabled: bool = true
@export var interaction_radius: float = 3.0

@export var indicator_node: Node3D:
	set(value):
		indicator_node = value
		_setup_indicator()

@export var indicator_icon: Texture2D:
	set(value):
		indicator_icon = value
		_update_indicator_texture()

signal player_interacted
signal player_started_look
signal player_ended_look

var key_ind: MeshInstance3D = null
var circle_ind: MeshInstance3D = null

var colliding: bool = false
var in_radius: bool = false
var _default_texture: Texture2D = null

func _ready():
	if not Engine.is_editor_hint():
		collision_layer &= ~1  # Disable layer 1
		collision_mask &= ~1   # Disable mask 1
		collision_layer |= 2   # Enable layer 2
		collision_mask |= 2    # Enable layer 2

	_setup_indicator()
	_update_mesh_visibility()

func _setup_indicator():
	if not indicator_node:
		key_ind = null
		circle_ind = null
		return

	# Search for children inside the indicator node
	key_ind = indicator_node.get_node_or_null("KeyInd") as MeshInstance3D
	if not key_ind:
		key_ind = indicator_node.find_child("KeyInd", true, false) as MeshInstance3D

	circle_ind = indicator_node.get_node_or_null("CircleInd") as MeshInstance3D
	if not circle_ind:
		circle_ind = indicator_node.find_child("CircleInd", true, false) as MeshInstance3D

	# Handle material duplication and base texture caching
	if key_ind:
		var mat = key_ind.get_surface_override_material(0)
		if mat:
			mat = mat.duplicate()
			key_ind.set_surface_override_material(0, mat)
			if mat is BaseMaterial3D and _default_texture == null:
				_default_texture = mat.albedo_texture

	_update_indicator_texture()

func _update_indicator_texture():
	if not key_ind:
		return

	var mat = key_ind.get_surface_override_material(0) as BaseMaterial3D
	if mat:
		if indicator_icon:
			mat.albedo_texture = indicator_icon
		else:
			mat.albedo_texture = _default_texture

func _process(_delta):
	if Engine.is_editor_hint():
		return

	if not Manager.player:
		return

	# Check distance to player
	var distance = global_position.distance_to(Manager.player.global_position)
	in_radius = distance <= interaction_radius

	# Check raycast targeting only if within radius
	var is_looking = false
	var raycast = Manager.player.item_raycast
	if in_radius and raycast and raycast.is_colliding():
		if raycast.get_collider() == self:
			is_looking = true

	# State transition for looking
	if is_looking and not colliding:
		colliding = true
		player_started_look.emit()
	elif not is_looking and colliding:
		colliding = false
		player_ended_look.emit()

	_update_mesh_visibility()

func _update_mesh_visibility():
	if Engine.is_editor_hint():
		return

	if not key_ind or not circle_ind:
		return

	if not enabled or not in_radius:
		key_ind.visible = false
		circle_ind.visible = false
		return

	if colliding:
		key_ind.visible = true
		circle_ind.visible = false
	else:
		key_ind.visible = false
		circle_ind.visible = true

func _input(_event):
	if Engine.is_editor_hint():
		return

	if Input.is_action_just_pressed("interact"):
		if colliding and in_radius and enabled:
			player_interacted.emit()

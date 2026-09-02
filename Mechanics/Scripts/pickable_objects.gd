extends RigidBody3D
class_name PickableObject

signal on_grabbed(hand_side: String)
signal on_released(hand_side: String)
signal picked_up(hand_side: String)
signal dropped()

@export var grab_target: GrabTarget

var is_grabbed: bool:
	get:
		if grab_target and is_instance_valid(grab_target):
			return grab_target.is_grabbed
		for child in find_children("*", "GrabTarget"):
			if child.is_grabbed:
				return true
		
		return is_held

var held_by: String = ""
var is_held: bool = false

var original_collision_layer: int = 1
var original_collision_mask: int = 1

func _ready() -> void:
	if not grab_target:
		grab_target = find_child("*", true, false) as GrabTarget
		
	original_collision_layer = collision_layer
	original_collision_mask = collision_mask
	add_collision_exception_with(Manager.player)

func pick_up(hand_side: String, hand_node: Node3D) -> void:
	if is_held:
		return
	held_by = hand_side
	is_held = true
	freeze = true
	
	
	# Explicitly wipe layer and mask, and disable internal shapes
	collision_layer = 0
	collision_mask = 0
	for child in find_children("*", "CollisionShape3D"):
		child.disabled = true
	for child in find_children("*", "CollisionPolygon3D"):
		child.disabled = true

	reparent(hand_node, true)
	if self.is_in_group("Battery"):
		position = Vector3.ZERO
	picked_up.emit(hand_side)
	on_grabbed.emit(hand_side)

func drop(impulse: Vector3 = Vector3.ZERO) -> void:
	if not is_held:
		return
	is_held = false
	held_by = ""
	reparent(get_tree().root, true)
	
	scale = Vector3.ONE
	
	# Restore collision layer/mask and shapes
	collision_layer = original_collision_layer
	collision_mask = original_collision_mask
	for child in find_children("*", "CollisionShape3D"):
		child.disabled = false
	for child in find_children("*", "CollisionPolygon3D"):
		child.disabled = false

	freeze = false
	apply_central_impulse(impulse)
	dropped.emit()
	on_released.emit("")

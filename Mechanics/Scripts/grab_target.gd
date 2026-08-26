@tool
extends Area3D
class_name GrabTarget

enum AllowedHand { BOTH, LEFT_ONLY, RIGHT_ONLY }
enum SwingType { Pull, Swing }
enum Hand { LEFT, RIGHT }
enum TransitionState {
	DEFAULT,
	FIRE,
	REVERSE,
	STRAIGHT,
	RETRACT,
	FINGER_TIPS,
	HALF,
	HANDLE_HALF,
	GRAB_HANDLE,
	SMALL_STRAIGHT_EDGE,
	STRAIGHT_EDGE,
	SPHERE
}

signal on_grabbed(hand_side: String)
signal on_pulled(hand_side: String)
signal on_released(hand_side: String)

@export var pickable_object: PickableObject

@export_category("Target Status")
@export var is_disabled: bool = false
@export var one_hand_at_a_time: bool = true

@export_category("Hand Restrictions")
@export var allowed_hand: AllowedHand = AllowedHand.BOTH
@export var allow_pulling: bool = true

@export_category("Target Movement & Alignment")
@export var affect_position: bool = true
@export var affect_rotation: bool = true
@export var stop_hand: bool = true
@export var use_marker_for_position: bool = true 
@export var use_marker_for_launch: bool = true   
@export var marker: Marker3D 
@export var override_anim: bool = false

@export var selected_animation: TransitionState = TransitionState.DEFAULT:
	set(value):
		selected_animation = value
		anim_name = _get_animation_name(value)
		if Engine.is_editor_hint() and show_preview:
			_update_preview_animation()

var anim_name: String = "Default"

@export_category("Retract Options")
@export var require_manual_retract_right_hand: bool = true 
@export var require_manual_retract_left_hand: bool = true  

@export_category("Swing Settings")
@export var is_swingable: bool = false
@export var swing_type: SwingType = SwingType.Swing
@export var swing_cable_length: float = 0.0      
@export var arc_dip_depth: float = 0.6           
@export var swing_speed_multiplier: float = 1.0  

@export_category("Custom Audio")
@export var use_custom_grab_sound: bool = false
@export var type: bool = false
@export var custom_grab_sound: AudioStream
@export var custom_release_sound: AudioStream

@export_category("Editor Hand Preview")
@export var show_preview: bool = false:
	set(value):
		show_preview = value
		if Engine.is_editor_hint() and is_inside_tree():
			if value:
				_create_preview()
			else:
				_clear_preview()

@export var preview_hand: Hand = Hand.LEFT:
	set(value):
		preview_hand = value
		if Engine.is_editor_hint() and show_preview:
			_update_preview_hand()

var current_claiming_hand: String = ""
var _preview_instance: Node = null
var is_grabbed: bool:
	get:
		return current_claiming_hand != ""

const preview_scene = preload("uid://qaf2k3ktfc55")

func _ready() -> void:
	self.add_to_group("HandTarget")
	anim_name = _get_animation_name(selected_animation)
	
	if Engine.is_editor_hint():
		if show_preview:
			call_deferred("_create_preview")
		else:
			call_deferred("_clear_preview")
	else:
		_remove_all_preview_instances()

func _exit_tree() -> void:
	if Engine.is_editor_hint():
		_clear_preview()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_sync_preview_transform()
		return

func _get_animation_name(enum_value: TransitionState) -> String:
	var key = TransitionState.keys()[enum_value]
	var parts = key.split("_")
	var result = ""
	for p in parts:
		result += p.capitalize()
	return result

func _remove_all_preview_instances() -> void:
	for child in get_children(true):
		if child == _preview_instance or (preview_scene and child.scene_file_path == preview_scene.resource_path):
			remove_child(child)
			child.queue_free()
	_preview_instance = null

func _create_preview() -> void:
	if not Engine.is_editor_hint() or preview_scene == null:
		return
	_remove_all_preview_instances()
	_preview_instance = preview_scene.instantiate()
	_preview_instance.name = "EditorPreviewHand"
	add_child(_preview_instance, false, Node.INTERNAL_MODE_BACK)
	_update_preview_hand()
	_update_preview_animation()
	_sync_preview_transform()

func _update_preview_hand() -> void:
	if _preview_instance and _preview_instance.is_inside_tree():
		if "current_hand" in _preview_instance:
			_preview_instance.set("current_hand", preview_hand)

func _update_preview_animation() -> void:
	if _preview_instance and _preview_instance.is_inside_tree():
		if "current_animation" in _preview_instance:
			_preview_instance.set("current_animation", selected_animation)

func _sync_preview_transform() -> void:
	if not _preview_instance or not is_instance_valid(_preview_instance):
		return
	if _preview_instance is Node3D and _preview_instance.is_inside_tree():
		var target_pos = marker.global_position if marker else global_position
		var target_rot = marker.global_rotation if marker else global_rotation
		_preview_instance.global_position = target_pos
		_preview_instance.global_rotation = target_rot

func _clear_preview() -> void:
	_remove_all_preview_instances()

func is_hand_allowed(hand_side: String) -> bool:
	if is_disabled:
		return false 
	if one_hand_at_a_time and current_claiming_hand != "" and current_claiming_hand != hand_side:
		return false 
	match allowed_hand:
		AllowedHand.BOTH:
			return true
		AllowedHand.LEFT_ONLY:
			return hand_side.to_lower() == "left"
		AllowedHand.RIGHT_ONLY:
			return hand_side.to_lower() == "right"
	return false

func claim_target(hand_side: String) -> void:
	if one_hand_at_a_time:
		current_claiming_hand = hand_side

func unclaim_target(hand_side: String) -> void:
	if current_claiming_hand == hand_side:
		current_claiming_hand = ""

func trigger_grab(hand_side: String = "") -> void:
	claim_target(hand_side)
	on_grabbed.emit(hand_side)

func trigger_pull(hand_side: String = "") -> void:
	if allow_pulling:
		on_pulled.emit(hand_side)

func trigger_release(hand_side: String = "") -> void:
	unclaim_target(hand_side)
	on_released.emit(hand_side)

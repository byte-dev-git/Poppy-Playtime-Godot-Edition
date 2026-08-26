@tool
extends Node

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

@export var current_animation: TransitionState = TransitionState.DEFAULT:
	set(value):
		current_animation = value
		_update_editor_animation(value)

@export var current_hand: Hand = Hand.LEFT:
	set(value):
		current_hand = value
		_update_hand(value)

# Lazy-loaded references (no @onready to avoid nil errors in editor)
var _right_mesh: MeshInstance3D = null
var _left_mesh: MeshInstance3D = null
var _animation_tree: AnimationTree = null

func _ready() -> void:
	_fetch_nodes()
	_update_hand(current_hand)
	_update_editor_animation(current_animation)

func _fetch_nodes() -> void:
	if not _right_mesh:
		_right_mesh = get_node("PreviewHand/SK_RedHand/Skeleton3D/Right") as MeshInstance3D
	if not _left_mesh:
		_left_mesh = get_node("PreviewHand/SK_RedHand/Skeleton3D/Left") as MeshInstance3D
	if not _animation_tree:
		_animation_tree = get_node("AnimationTree") as AnimationTree

func _update_hand(state: Hand) -> void:
	_fetch_nodes()
	if not _right_mesh or not _left_mesh:
		return
	match state:
		Hand.RIGHT:
			_right_mesh.visible = true
			_left_mesh.visible = false
		Hand.LEFT:
			_right_mesh.visible = false
			_left_mesh.visible = true

func _update_editor_animation(state: TransitionState) -> void:
	_fetch_nodes()
	if not _animation_tree or not _animation_tree.is_inside_tree():
		return
	_animation_tree.active = true
	var prop = "parameters/Transition/transition_request"
	match state:
		TransitionState.DEFAULT:         _animation_tree.set(prop, "Default")
		TransitionState.FIRE:            _animation_tree.set(prop, "Fire")
		TransitionState.REVERSE:         _animation_tree.set(prop, "Reverse")
		TransitionState.STRAIGHT:        _animation_tree.set(prop, "Straight")
		TransitionState.RETRACT:         _animation_tree.set(prop, "Retract")
		TransitionState.FINGER_TIPS:     _animation_tree.set(prop, "FingerTips")
		TransitionState.HALF:            _animation_tree.set(prop, "Half")
		TransitionState.HANDLE_HALF:     _animation_tree.set(prop, "HandleHalf")
		TransitionState.GRAB_HANDLE:     _animation_tree.set(prop, "GrabHandle")
		TransitionState.SMALL_STRAIGHT_EDGE: _animation_tree.set(prop, "SmallStraightEdge")
		TransitionState.STRAIGHT_EDGE:   _animation_tree.set(prop, "SraightEdge")  # keep your typo
		TransitionState.SPHERE:          _animation_tree.set(prop, "Sphere")

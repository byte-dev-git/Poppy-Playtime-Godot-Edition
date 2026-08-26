@tool
extends StaticBody3D

enum Hands {
	RedHand,
	PressureHand,
	ConductiveHand
}

signal scan_complete
signal scanning
signal scan_failed

@export var is_off: bool = false:
	set(value):
		is_off = value
		if is_inside_tree():
			if is_off:
				stop_all_audio()
				if timer and not timer.is_stopped():
					timer.stop()
				if anim and anim.is_playing():
					anim.stop()
			_update_visuals()
			if not is_off:
				set_state(current_state)

@export var is_left: bool = true:
	set(value):
		is_left = value
		_update_visuals()

@export var hand: Hands = Hands.RedHand

@export var hand_color: Color = Color.RED:
	set(value):
		hand_color = value
		_update_visuals()

@export var scan_time: float = 3.0

@onready var mesh: MeshInstance3D = $SM_HandScanner_w_wire_Proxy/Mesh
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var hand_texture: TextureRect = $HandScanner/SubViewport/T_HandScanner
@onready var hand_viewport: SubViewport = $HandScanner/SubViewport
@onready var scanning_loop: AudioStreamPlayer3D = $SwSfxHandscannerScanningLoop
@onready var fail: AudioStreamPlayer3D = $SwKeypadFail
@onready var unlock: AudioStreamPlayer3D = $SwKeypadUnlock
@onready var timer: Timer = $Timer
@onready var left_grab: Area3D = $LeftGrabTarget
@onready var right_grab: Area3D = $RightGrabTarget

const T_DENIED_TEXT = preload("uid://c2pqlxb0w75g8")
const T_HAND_SCANNER = preload("uid://byqer5u4ur8dn")
const T_OMNI_HAND_SCANNER_MASK = preload("uid://o36fmw68s0iu")
const T_VERIFIED_TEXT = preload("uid://bgpoairwsgw7a")

var HandMaterial: StandardMaterial3D
var TextMaterial: StandardMaterial3D
var powered: bool = false
var current_state: int = 0
var current_hand_side: String = ""
var is_grabbed: bool = false

func _ready() -> void:
	_update_visuals()
	if not Engine.is_editor_hint():
		if not is_off:
			set_state(0)
		if fail.playing: fail.stop()

func _update_visuals() -> void:
	if not is_inside_tree():
		return
	
	HandMaterial = mesh.get_surface_override_material(2) as StandardMaterial3D
	TextMaterial = mesh.get_surface_override_material(3) as StandardMaterial3D

	if is_off:
		if HandMaterial:
			HandMaterial.albedo_color = Color.BLACK
		if TextMaterial:
			TextMaterial.albedo_color = Color.BLACK
		if hand_texture:
			hand_texture.texture = null
		_update_grab_visibility()
		return

	if HandMaterial:
		if is_left:
			HandMaterial.uv1_scale = Vector3(1.0, 1.0, 1.0)
			if current_state in [0, 1, 2]:
				HandMaterial.albedo_color = Color.ROYAL_BLUE
		else:
			HandMaterial.uv1_scale = Vector3(-1.0, 1.0, 1.0)
			if current_state in [0, 1, 2]:
				HandMaterial.albedo_color = hand_color

		if TextMaterial:
			if is_left:
				if current_state in [0, 1, 2]:
					TextMaterial.albedo_color = Color.ROYAL_BLUE
			else:
				if current_state in [0, 1, 2]:
					TextMaterial.albedo_color = hand_color
	_update_grab_visibility()

func _update_grab_visibility() -> void:
	left_grab.visible = is_left and not powered and not is_off
	right_grab.visible = not is_left and not powered and not is_off
	left_grab.is_disabled = not left_grab.visible
	right_grab.is_disabled = not right_grab.visible

func stop_all_audio() -> void:
	if Engine.is_editor_hint():
		return
	if scanning_loop and scanning_loop.playing:
		scanning_loop.stop()
	if fail and fail.playing:
		fail.stop()
	if unlock and unlock.playing:
		unlock.stop()

func set_state(state: int) -> void:
	current_state = state
	stop_all_audio()
	_update_visuals()
	
	if is_off:
		return

	if current_state == 3:
		if HandMaterial: HandMaterial.albedo_color = Color.GREEN
		if TextMaterial: TextMaterial.albedo_color = Color.GREEN
	elif current_state == 4:
		if HandMaterial: HandMaterial.albedo_color = Color.CRIMSON
		if TextMaterial: TextMaterial.albedo_color = Color.CRIMSON

	if hand_texture:
		match current_state:
			0, 1:
				hand_texture.texture = T_HAND_SCANNER
			3:
				hand_texture.texture = T_VERIFIED_TEXT
			4:
				hand_texture.texture = T_DENIED_TEXT

	if Engine.is_editor_hint():
		return

	match current_state:
		0:
			if anim: anim.play("ready")
			if fail and !is_grabbed: fail.play()
		1:
			if anim: anim.play("scanning")
			if scanning_loop: scanning_loop.play()
		3:
			if anim: anim.play("verified")
			if unlock: unlock.play()
		4:
			if anim: anim.play("error")
			if fail: fail.play()
			await get_tree().create_timer(1.5).timeout
			if current_state == 4 and not is_off:
				set_state(0)

func _on_grab_target_on_grabbed(hand_side: String) -> void:
	if Engine.is_editor_hint() or powered or is_off:
		return
	if current_state == 0:
		is_grabbed = true
		current_hand_side = hand_side
		set_state(1)
		scanning.emit()
		timer.start(scan_time)

func _on_grab_target_on_released(_hand_side: String) -> void:
	if Engine.is_editor_hint() or is_off:
		return
	is_grabbed = false
	if powered:
		return
	if current_state == 1:
		fail.play()
		timer.stop()
		set_state(0)

func _on_timer_timeout() -> void:
	if Engine.is_editor_hint() or not is_grabbed or current_state != 1 or is_off:
		return
	
	var is_correct_hand: bool = false
	
	if is_left:
		is_correct_hand = (current_hand_side == "left")
	else:
		var node_matches: bool = false
		if Manager.right_hand != null and Manager.right_hand.current_hand_node != null:
			var hand_name: String = Hands.find_key(hand)
			node_matches = (Manager.right_hand.current_hand_node.name == hand_name)
		is_correct_hand = (current_hand_side == "right") and node_matches
	
	if is_correct_hand:
		powered = true
		if current_hand_side == "right":
			Manager.right_hand.start_retract()
		elif current_hand_side == "left":
			Manager.left_hand.start_retract()
		set_state(3)
		scan_complete.emit()
	else:
		if current_hand_side == "right":
			Manager.right_hand.start_retract()
		elif current_hand_side == "left":
			Manager.left_hand.start_retract()
		set_state(4)
		scan_failed.emit()

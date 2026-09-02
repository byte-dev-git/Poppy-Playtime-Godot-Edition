extends Node3D

enum HandState { IDLE, LAUNCHING, ATTACHED, PULLING, RETRACTING, HOLDING }
var current_state: HandState = HandState.IDLE

var max_range = 30.0
var launch_speed: float = 25.0
var retract_speed: float = 30.0
var stick_time: float = 0.35
var surface_push_offset: float = 0.015
var initial_scale: Vector3 = Vector3(0.95, 0.95, 0.95)
var exit_scale_multiplier: float = 2.0
var exit_grow_speed_factor: float = 1.4
var use_camera_raycast: bool = true
var camera_raycast_range: float = 100.0
var camera_collision_mask: int = 1
var surface_hit_item_rotation_deg: float = 0.0
var surface_slide_offset: float = -0.045

@export_category("Hand Audio")
@export var launch_sounds: Array[AudioStream]
@export var retract_sounds: Array[AudioStream]
@export var retract_loop_audio: AudioStream
@export var hand_grab_audio: AudioStream
@export var switch_sound: AudioStream
@export var grab_sounds: Array[AudioStream]
@export var release_sounds: Array[AudioStream]

@onready var hand_pos: Node3D = $".."
@onready var player: CharacterBody3D = $"../../../../../../.."
@onready var retract_audio_player: AudioStreamPlayer3D = $"../../RightHandAudio"

@onready var raycast: RayCast3D = $RayCast3D
@onready var finger_rays: Node3D = $FigerRays
@onready var cable: CablePhysics = $"../CablePhysics"
@onready var sk_right_hand: Node3D = $SK_RightHand
@onready var anim_tree: AnimationTree = $AnimationTree
@onready var item_pos: Node3D = $ItemPos

@onready var grabpack: Node3D = $"../../../../../.."
@onready var grabpack_anim_tree: AnimationTree = $"../../../../../AnimationTree"
@onready var timer: Timer = $Timer

@onready var camera: Camera3D = $"../../../../../../../Neck/Camera3D"
@onready var camera_raycast: RayCast3D = $"../../../../../../../Neck/Camera3D/RayCast3D"
@onready var item_raycast: RayCast3D = $"../../../../../../../Neck/Camera3D/ItemRaycast"

@onready var lean_modifier: BoneMultiModifier = $"../../../RightHandLean"
@onready var right_tube: JacobianIK3D = $"../../../RightTubeIK"

@onready var hands_container: Node3D = $Hands

var on_wall: bool = false

var retract_path: Array[Vector3] = []

var launch_start_position: Vector3
var launch_target_position: Vector3
var launch_duration: float = 0.0
var launch_elapsed: float = 0.0

var hit_surface_normal: Vector3 = Vector3.UP
var hit_normal_local: Vector3 = Vector3.ZERO
var will_hit_surface: bool = false
var stick_timer: float = 0.0

var current_hit_type: String = "none"
var current_target_node: Node3D = null

var hit_offset_local: Vector3 = Vector3.ZERO
var hit_basis_local: Basis = Basis()

var has_released_after_launch: bool = false
var hold_to_pull_timer: float = 0.0

var switching: bool = false

@export_category("Hand Settings")
@export var hands: Array[PackedScene] = [
	preload("uid://5fs63oguxlgo"),
	preload("uid://mewvtluapv75")
]

var hand_queue: int = 0
var current_hand: int = 0
var current_hand_node: Node3D = null
var awaiting_switch: bool = false
var disabled: bool = false

var is_radial_menu_open: bool = false
var radial_selected_index: int = 0
var screen_center: Vector2 = Vector2.ZERO

var allow_pulling: bool

var held_object: PickableObject = null
var is_held: bool = false

var initial_item_pos_rotation: Vector3 = Vector3.ZERO
var is_item_pos_rotated: bool = false

func _ready() -> void:
	top_level = false
	position = Vector3.ZERO
	rotation = Vector3.ZERO
	scale = initial_scale
	$Hands/RedHand.queue_free()
	screen_center = get_viewport().get_visible_rect().size / 2.0

	if item_pos:
		initial_item_pos_rotation = item_pos.rotation

	if player:
		if raycast:
			raycast.add_exception(player)
			raycast.hit_back_faces = true
			raycast.hit_from_inside = true
		if camera_raycast:
			camera_raycast.add_exception(player)

	if camera_raycast:
		camera_raycast.target_position = Vector3(0, 0, -camera_raycast_range)
		camera_raycast.enabled = true
		camera_raycast.collide_with_areas = false
		camera_raycast.hit_back_faces = true
		camera_raycast.hit_from_inside = true

	if item_raycast:
		item_raycast.collide_with_areas = true
		item_raycast.hit_back_faces = true
		item_raycast.hit_from_inside = true

	if hands.size() > 0:
		set_hand(0)
		play_animation("Retract")

func _unhandled_input(event: InputEvent) -> void:
	if hands.size() == 0 or disabled:
		return

	if event.is_action_pressed("hand_wheel"):
		is_radial_menu_open = true

	elif event.is_action_released("hand_wheel"):
		is_radial_menu_open = false
		if current_state == HandState.IDLE and queue_test(radial_selected_index):
			switch_hand(1, radial_selected_index)

	if is_radial_menu_open and event is InputEventMouseMotion:
		var mouse_pos = event.position
		var dir = screen_center.direction_to(mouse_pos)

		var angle = Vector2.UP.angle_to(dir)
		if angle < 0:
			angle += TAU

		var slice_size = TAU / hands.size()
		var shifted_angle = fmod(angle + (slice_size / 2.0), TAU)
		radial_selected_index = int(shifted_angle / slice_size) % hands.size()

	if is_radial_menu_open or current_state != HandState.IDLE:
		return

	if Input.is_action_just_pressed("hand_up") or event.is_action_pressed("switch_up"):
		switch_hand(1, current_hand + 1)
	elif Input.is_action_just_pressed("hand_down") or event.is_action_pressed("switch_down"):
		switch_hand(1, current_hand - 1)

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_0 and event.keycode <= KEY_9:
			var switch_num: int = event.keycode - KEY_0
			if queue_test(switch_num - 1):
				switch_hand(1, switch_num - 1)

func queue_test(hand_index: int) -> bool:
	var test_queue: int = hand_index
	if test_queue < 0:
		test_queue = 0
	if test_queue > hands.size() - 1:
		test_queue = hands.size() - 1
	if test_queue == current_hand:
		return false
	return true

func queue_hand(hand_index: int) -> void:
	hand_queue = hand_index
	if hand_queue < 0:
		hand_queue = 0
	if hand_queue > hands.size() - 1:
		hand_queue = hands.size() - 1

func queue_hand_switch(hand_index: int) -> void:
	if disabled:
		return
	queue_hand(hand_index)
	awaiting_switch = true

func switch_hand(type: int, new_hand: int) -> void:
	if player.is_grabpack_lowered == true: return
	if current_state != HandState.IDLE: return
	if disabled: return
	if switching: return
	
	timer.start(0.8)
	switching = true
	$"../../../RightTubeIK".influence = 0.0
	
	if new_hand > hands.size() - 1:
		new_hand = 0
	elif new_hand < 0:
		new_hand = hands.size() - 1

	queue_hand(new_hand)
	grabpack_anim_tree.set("parameters/Switch/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	
	await get_tree().create_timer(0.25).timeout
	if switch_sound:
		_play_one_shot(switch_sound)

func set_hand(hand_index: int) -> void:
	if current_hand_node != null:
		current_hand_node.queue_free()
		current_hand_node = null

	var new_hand = hands[hand_index].instantiate()
	hands_container.add_child(new_hand)

	current_hand_node = new_hand
	current_hand = hand_index

func set_queued_hand() -> void:
	set_hand(hand_queue)

func play_animation(anim_name: String) -> void:
	if is_held:
		if anim_name in ["Retract", "Reverse", "HitWall", "WallHit"]:
			return
		var held_anim = _get_held_anim_name()
		if held_anim != "":
			anim_name = held_anim

	if current_hand_node:
		var anim_tree = current_hand_node.get_node_or_null("AnimationTree")
		if anim_tree and anim_name != "":
			anim_tree.set("parameters/Transition/transition_request", anim_name)

func disable_hand() -> void:
	disabled = true

func enable_hand() -> void:
	disabled = false

func _process(delta: float) -> void:
	if current_state != HandState.RETRACTING and current_state != HandState.HOLDING:
		if current_state != HandState.IDLE:
			await get_tree().create_timer(0.05).timeout
			lean_modifier.lookat_influence = lerp(lean_modifier.lookat_influence, 1.0, 12.0 * delta)
			right_tube.active = true
		else:
			lean_modifier.lookat_influence = lerp(lean_modifier.lookat_influence, 0.0, 12.0 * delta)
			right_tube.active = false
	else:
		lean_modifier.lookat_influence = lerp(lean_modifier.lookat_influence, 0.0, 12.0 * delta)
		right_tube.active = false

	if current_state == HandState.ATTACHED or current_state == HandState.PULLING:
		if has_node("FigerRays/Finger2") and not $FigerRays/Finger2.is_colliding():
			if has_node("FigerRays/Finger3") and not $FigerRays/Finger3.is_colliding():
				play_animation("SraightEdge" if has_node("FigerRays/Finger1") and not $FigerRays/Finger1.is_colliding() else "HandleHalf")
			else:
				play_animation("FingerTips")
		else:
			play_animation("Straight")

		if not is_held:
			if current_hit_type == "pullable":
				var ray1_colliding = $FigerRays/RotationRay2.is_colliding() if has_node("FigerRays/RotationRay2") else false
				var ray2_colliding = $FigerRays/RotationRay1.is_colliding() if has_node("FigerRays/RotationRay1") else false

				var rot_change: float = 0.0
				if not ray1_colliding and ray2_colliding:
					rot_change = -90.0 * delta
				elif not ray2_colliding and ray1_colliding:
					rot_change = 90.0 * delta

				if rot_change != 0.0:
					hit_basis_local = hit_basis_local * Basis(Vector3.FORWARD, rot_change)
			elif current_hit_type == "surface":
				var ray1_colliding = $FigerRays/RotationRay1.is_colliding() if has_node("FigerRays/RotationRay1") else false
				var ray2_colliding = $FigerRays/RotationRay2.is_colliding() if has_node("FigerRays/RotationRay2") else false

				var rot_change: float = 0.0
				if not ray1_colliding and ray2_colliding:
					rot_change = -20.0 * delta
				elif not ray2_colliding and ray1_colliding:
					rot_change = 20.0 * delta

				if rot_change != 0.0:
					rotation.z += rot_change

func _physics_process(delta: float) -> void:
	var target_needs_manual_retract: bool = _target_requires_manual_retract()

	if awaiting_switch and current_state == HandState.IDLE:
		current_hand = -1
		switch_hand(1, hand_queue)
		awaiting_switch = false

	if current_state == HandState.IDLE:
		_reset_item_pos_rotation()
		if Input.is_action_just_pressed("right_hand"):
			launch()
	elif not player.is_grabpack_lowered:
		if current_state == HandState.HOLDING:
			if Input.is_action_just_pressed("right_hand"):
				hold_to_pull_timer = 0.0

			if Input.is_action_pressed("right_hand"):
				hold_to_pull_timer += delta
				if hold_to_pull_timer >= 0.75:
					pickup_target(false)
					hold_to_pull_timer = 0.0
			elif Input.is_action_just_pressed("drop_item"):
				pickup_target(false)
				hold_to_pull_timer = 0.0
			elif Input.is_action_just_released("right_hand"):
				if hold_to_pull_timer > 0.0 and hold_to_pull_timer < 0.75:
					launch()
				hold_to_pull_timer = 0.0
	
	if player.is_grabpack_lowered:
		if current_state != HandState.IDLE:
			if current_state != HandState.HOLDING:
				start_retract()
	
	if is_held:
		surface_push_offset = 0.2
	elif !is_held:
		surface_push_offset = 0.015
	
	if current_hit_type == "target" and current_target_node and is_instance_valid(current_target_node):
		var pullable = current_target_node.get("allow_pulling")
		allow_pulling = pullable
	
	if not Input.is_action_pressed("right_hand"):
		has_released_after_launch = true
		if current_state == HandState.PULLING:
			start_retract()
			return
		elif not allow_pulling:
			if current_state == HandState.ATTACHED and current_hit_type == "target" and not target_needs_manual_retract:
				var stop_hand = true
				if current_target_node and is_instance_valid(current_target_node):
					stop_hand = current_target_node.get("stop_hand") if "stop_hand" in current_target_node else true
				if stop_hand:
					start_retract()
					return

	if has_released_after_launch and Input.is_action_just_pressed("right_hand"):
		if current_state == HandState.LAUNCHING:
			start_retract()
			return
		elif current_state == HandState.ATTACHED:
			if not allow_pulling:
				if current_hit_type == "target" and target_needs_manual_retract:
					var stop_hand = true
					if current_target_node and is_instance_valid(current_target_node):
						stop_hand = current_target_node.get("stop_hand") if "stop_hand" in current_target_node else true
					if stop_hand:
						start_retract()
						return
	match current_state:
		HandState.IDLE:
			scale = initial_scale
			_reset_item_pos_rotation()
			if top_level:
				top_level = false
				position = Vector3.ZERO
				rotation = Vector3.ZERO
			
		HandState.HOLDING:
			scale = initial_scale
			if top_level:
				top_level = false
				position = Vector3.ZERO
				rotation = Vector3.ZERO

			if is_held and is_instance_valid(held_object):
				var held_anim = _get_held_anim_name()
				if held_anim != "":
					play_animation(held_anim)
		
		HandState.LAUNCHING:
			if current_hit_type == "target" and is_instance_valid(current_target_node):
				var marker = current_target_node.get("marker") if "marker" in current_target_node else null
				var launch_pos = current_target_node.get("use_marker_for_launch") if "use_marker_for_launch" in current_target_node else true
				if marker and is_instance_valid(marker):
					if launch_pos == true: launch_target_position = marker.global_position
				else:
					launch_target_position = current_target_node.global_position
			
			launch_elapsed += delta
			var t: float = 1.0
			if launch_duration > 0.0:
				t = clamp(launch_elapsed / launch_duration, 0.0, 1.0)

			var next_position: Vector3 = launch_start_position.lerp(launch_target_position, t)

			# 1. Mid-flight Collision Check
			if global_position.distance_squared_to(next_position) > 0.0001:
				var hit = _cast_through_disabled(camera_collision_mask, global_position, next_position, "right")
				if hit:
					var col = hit.collider
					var pickable = col if col is PickableObject else (col.get_parent() if col.get_parent() is PickableObject else null)

					if _is_valid_grab_target(col):
						var is_allowed = true
						if col.has_method("is_hand_allowed"):
							is_allowed = col.is_hand_allowed("right")
						if is_allowed:
							current_hit_type = "target"
							current_target_node = col
							next_position = hit.position
							t = 1.0
							will_hit_surface = true
							hit_surface_normal = hit.normal
							launch_target_position = hit.position
					elif pickable and not is_held and not _is_pickable_already_held(pickable):
						current_hit_type = "pickable"
						current_target_node = pickable
						next_position = hit.position
						t = 1.0
						will_hit_surface = true
						hit_surface_normal = hit.normal
						launch_target_position = hit.position
					else:
						if col is PullableObject and not is_held:
							current_hit_type = "pullable"
							current_target_node = col
						else:
							current_hit_type = "surface"
							current_target_node = null
						
						will_hit_surface = true
						hit_surface_normal = hit.normal
						
						# Pre-calculate the slide offset for the mid-flight impact
						var temp_trans = global_transform
						_align_to_surface(hit_surface_normal)
						var slide_vector = global_transform.basis * Vector3(0, surface_slide_offset, 0)
						global_transform = temp_trans
						
						launch_target_position = hit.position + slide_vector
						next_position = launch_target_position
						t = 1.0

			var grow_t: float = min(t * exit_grow_speed_factor, 1.0)
			scale = initial_scale.lerp(initial_scale * exit_scale_multiplier, grow_t)

			global_position = next_position

			# 2. Destination Arrival
			if t >= 1.0:
				hold_to_pull_timer = 0.0
				play_animation("Straight")

				if current_hit_type == "target" and current_target_node and is_instance_valid(current_target_node):
					var type = current_target_node.get("type") if "type" in current_target_node else true
					if "custom_grab_sound" in current_target_node and current_target_node.custom_grab_sound:
						_play_one_shot(current_target_node.custom_grab_sound, 250.0)
					else:
						_play_grab_sound(true if type else false)

					if current_target_node.has_method("trigger_grab"):
						current_target_node.trigger_grab("right")
					if not is_instance_valid(current_target_node):
						return
					var stop_hand = current_target_node.get("stop_hand") if "stop_hand" in current_target_node else true
					var marker = current_target_node.get("marker") if "marker" in current_target_node else null
					var do_pos = current_target_node.get("affect_position") if "affect_position" in current_target_node else true
					var do_rot = current_target_node.get("affect_rotation") if "affect_rotation" in current_target_node else true

					current_state = HandState.ATTACHED
					var anchor = current_target_node.global_position

					if marker:
						anchor = marker.global_position
						if do_pos:
							global_position = marker.global_position
						else:
							global_position = launch_target_position + (hit_surface_normal * surface_push_offset)

						if do_rot:
							global_rotation = marker.global_rotation
						else:
							_align_to_surface(hit_surface_normal)
					else:
						global_position = launch_target_position + (hit_surface_normal * surface_push_offset)
						_align_to_surface(hit_surface_normal)

					if stop_hand:
						if current_target_node.get("is_swingable"):
							player.swinging_point = anchor
							player.swinging = true
							if player.has_node("HookController"):
								player.hook_controller._launch_hook(anchor)
					else:
						stick_timer = stick_time

				elif current_hit_type == "pickable" and current_target_node and is_instance_valid(current_target_node):
					if not _is_pickable_already_held(current_target_node):
						current_state = HandState.ATTACHED
						_play_grab_sound(false)
						start_retract()
					else:
						start_retract()

				elif current_hit_type == "pullable" and current_target_node:
					current_state = HandState.ATTACHED
					_play_grab_sound(false)
					hit_offset_local = current_target_node.to_local(launch_target_position)
					hit_normal_local = current_target_node.global_transform.basis.inverse() * hit_surface_normal
					var offset_local = hit_offset_local + hit_normal_local * surface_push_offset
					global_position = current_target_node.to_global(offset_local)
					_align_to_surface(hit_surface_normal)
					var collider_rot = current_target_node.global_transform.basis.orthonormalized()
					var hand_rot = global_transform.basis.orthonormalized()
					hit_basis_local = collider_rot.inverse() * hand_rot

				elif current_hit_type == "surface" and will_hit_surface:
					current_state = HandState.ATTACHED
					if current_hand_node.name == "ConductiveHand":
						current_hand_node.play_impact()
					global_position = launch_target_position + (hit_surface_normal * surface_push_offset)
					_align_to_surface(hit_surface_normal)
					_apply_item_pos_surface_rotation()
					stick_timer = stick_time

				else:
					start_retract()

		HandState.ATTACHED:
			if current_hit_type == "target" and current_target_node and is_instance_valid(current_target_node):
				var stop_hand = current_target_node.get("stop_hand") if "stop_hand" in current_target_node else true
				var do_pos = current_target_node.get("affect_position") if "affect_position" in current_target_node else true
				var do_rot = current_target_node.get("affect_rotation") if "affect_rotation" in current_target_node else true
				var marker = current_target_node.get("marker") if "marker" in current_target_node else null
				var anim_override = current_target_node.get("override_anim")
				var anim_name = current_target_node.get("anim_name")
				if marker:
					if do_pos:
						global_position = marker.global_position
					if do_rot:
						global_rotation = marker.global_rotation
				if anim_override and anim_name:
					play_animation(anim_name)

				if stop_hand:
					if has_released_after_launch and allow_pulling:
						if Input.is_action_just_pressed("right_hand"):
							hold_to_pull_timer = 0.0

						if Input.is_action_pressed("right_hand"):
							hold_to_pull_timer += delta
							if hold_to_pull_timer >= 0.15:
								start_pulling()
						elif Input.is_action_just_released("right_hand"):
							if hold_to_pull_timer > 0.0 and hold_to_pull_timer < 0.15:
								start_retract()
							hold_to_pull_timer = 0.0
				else:
					stick_timer -= delta
					if stick_timer <= 0.0:
						start_retract()

			elif current_hit_type == "pullable" and current_target_node and is_instance_valid(current_target_node):
				var current_scale = global_transform.basis.get_scale()
				var offset_local = hit_offset_local + hit_normal_local * surface_push_offset
				global_position = current_target_node.to_global(offset_local)

				var target_rot = current_target_node.global_transform.basis.orthonormalized()
				global_transform.basis = (target_rot * hit_basis_local).orthonormalized().scaled(current_scale)

				var pull_target = _get_pull_target()

				if current_target_node is PullableObject:
					var drag_dir = (pull_target - current_target_node.global_position).normalized()
					current_target_node.apply_central_force(drag_dir * 1.5)

				if has_released_after_launch:
					if Input.is_action_just_pressed("right_hand"):
						hold_to_pull_timer = 0.0

					if Input.is_action_pressed("right_hand"):
						hold_to_pull_timer += delta
						if hold_to_pull_timer >= 0.15:
							start_pulling()
					elif Input.is_action_just_released("right_hand"):
						if hold_to_pull_timer > 0.0 and hold_to_pull_timer < 0.15:
							if current_target_node is PullableObject:
								var yank_dir = (pull_target - current_target_node.global_position).normalized()
								current_target_node.apply_central_impulse(yank_dir * 6.0 + Vector3.UP * 1.5)
							start_retract()
						hold_to_pull_timer = 0.0
			else:
				on_wall = true
				stick_timer -= delta
				if stick_timer <= 0.0:
					on_wall = false
					start_retract()

		HandState.PULLING:
			if current_target_node and is_instance_valid(current_target_node):
				if current_hit_type == "target":
					var anim_name = current_target_node.get("anim_name")
					if anim_name and anim_name != "":
						play_animation(anim_name)
					if "marker" in current_target_node and is_instance_valid(current_target_node.marker):
						global_position = current_target_node.marker.global_position
					elif current_target_node.has_node("PullMark"):
						global_position = current_target_node.get_node("PullMark").global_position
				else:
					var current_scale = global_transform.basis.get_scale()
					var offset_local = hit_offset_local + hit_normal_local * surface_push_offset
					global_position = current_target_node.to_global(offset_local)

					var target_rot = current_target_node.global_transform.basis.orthonormalized()
					global_transform.basis = (target_rot * hit_basis_local).orthonormalized().scaled(current_scale)

					if current_target_node.has_method("update_pull_target"):
						current_target_node.update_pull_target("right", _get_pull_target())

		HandState.RETRACTING:
			_reset_item_pos_rotation()
			var target_position: Vector3 = retract_path[0] if retract_path.size() > 0 else hand_pos.global_position
			
			var step = retract_speed * delta
			global_position = global_position.move_toward(target_position, step)

			if global_position.distance_to(target_position) > 0.05:
				var up_dir = Vector3.UP
				if abs(global_position.direction_to(target_position).y) > 0.99:
					up_dir = Vector3.FORWARD
				look_at(target_position, up_dir)

			scale = scale.move_toward(initial_scale, delta * 5.0)
			
			if not is_held: play_animation("Reverse")
			
			if global_position.distance_to(target_position) < 0.1:
				if retract_path.size() > 0:
					retract_path.pop_front()
					if cable and cable.rope_points.size() > 2:
						cable.rope_points.remove_at(cable.rope_points.size() - 2)
						cable.rope_normals.remove_at(cable.rope_normals.size() - 2)
				else:
					# Snap back into local space relative to hand_pos
					top_level = false
					position = Vector3.ZERO
					rotation = Vector3.ZERO
					scale = initial_scale
					cable.is_active = false

					if is_held:
						current_state = HandState.HOLDING
					else:
						current_state = HandState.IDLE
						play_animation("Retract")

					if launch_sounds.size() > 0:
						_play_one_shot(retract_sounds.pick_random())

	if current_state in [HandState.LAUNCHING, HandState.RETRACTING, HandState.PULLING]:
		cable_sound(true)
	else:
		cable_sound(false)

func _cast_through_disabled(mask: int, start: Vector3, end: Vector3, hand_side: String) -> Dictionary:
	var space_state := get_world_3d().direct_space_state
	var current_start = start
	var max_iterations = 10
	var exclusions: Array[RID] = []
	if player:
		exclusions.append(player.get_rid())

	for i in range(max_iterations):
		var query := PhysicsRayQueryParameters3D.create(current_start, end, mask)
		query.collide_with_areas = true
		query.hit_back_faces = true
		query.hit_from_inside = true
		query.exclude = exclusions

		var hit := space_state.intersect_ray(query)
		if hit.is_empty():
			return {}

		var col = hit.collider
		if col is GrabTarget:
			if _is_valid_grab_target(col):
				var allowed = true
				if col.has_method("is_hand_allowed"):
					allowed = col.is_hand_allowed(hand_side)
				
				if allowed:
					return hit
				else:
					exclusions.append(col.get_rid())
					continue
			else:
				# Exclude disabled GrabTargets (such as an empty BatteryHolder when not holding a battery)
				exclusions.append(col.get_rid())
				continue
		else:
			return hit

	return {}

func _is_valid_grab_target(col: Node) -> bool:
	if not (col is GrabTarget):
		return false
	
	# BatteryHolder targets: ONLY valid if holding a Battery
	if col.is_in_group("BatteryHolder"):
		return is_held and is_instance_valid(held_object) and held_object.is_in_group("Battery")
	
	# Standard GrabTargets: ONLY valid when NOT holding any object
	return not is_held

func _is_pickable_already_held(pickable: Node3D) -> bool:
	if not is_instance_valid(pickable):
		return false
	if "is_held" in pickable and pickable.is_held:
		return true
	# Find the opposite hand via group
	var group_name = "rightHand" if name != "rightHand" else "RightHand"
	var other_hand = get_tree().get_first_node_in_group(group_name)
	if other_hand and "held_object" in other_hand and other_hand.held_object == pickable:
		return true
	return false

func _is_target_busy(target_node: Node) -> bool:
	var left_hand = get_tree().get_first_node_in_group("LeftHand")
	if left_hand and is_instance_valid(left_hand):
		# Block if left hand is holding or actively flying towards this node
		if left_hand.held_object == target_node or left_hand.current_target_node == target_node:
			return true
	return false

func _target_requires_manual_retract() -> bool:
	if current_target_node and is_instance_valid(current_target_node) and "require_manual_retract_right_hand" in current_target_node:
		return current_target_node.require_manual_retract_right_hand
	return false

func _get_pull_target() -> Vector3:
	if cable == null or cable.rope_points.size() <= 2:
		return player.global_position

	var pull_target: Vector3 = cable.rope_points[0]
	var min_dist: float = INF

	for i in range(cable.rope_points.size() - 1):
		var pt = cable.rope_points[i]
		var dist = global_position.distance_to(pt)
		if dist < min_dist:
			min_dist = dist
			pull_target = pt

	return pull_target

func cable_sound(on: bool) -> void:
	if on:
		if retract_loop_audio and not retract_audio_player.playing:
			retract_audio_player.stream = retract_loop_audio
			retract_audio_player.play()
	else:
		if retract_audio_player.playing:
			retract_audio_player.stop()

func launch() -> void:
	if current_hand_node.name == "FlareGun":
		current_hand_node._shoot()
		return
	
	if grabpack_anim_tree.get("parameters/Switch/active") == true:
		return
	if player and player.is_grabpack_lowered:
		return
	if (current_state != HandState.IDLE and current_state != HandState.HOLDING) or disabled:
		return

	allow_pulling = false
	cable.is_active = true
	player.hand_InOut(true, true)
	has_released_after_launch = false

	current_hit_type = "surface"
	current_target_node = null
	hit_offset_local = Vector3.ZERO
	hit_normal_local = Vector3.ZERO
	hit_basis_local = Basis()
	hold_to_pull_timer = 0.0
	current_state = HandState.LAUNCHING

	# Enable top_level to detach movement from hand_pos during flight
	top_level = true
	launch_start_position = hand_pos.global_position
	global_position = launch_start_position
	global_rotation = hand_pos.global_rotation
	scale = initial_scale
	launch_elapsed = 0.0
	
	var aim: Dictionary = _get_aim_target()
	launch_target_position = aim.position
	if camera and aim.hit_type != "target" and aim.hit:
		var side_dir = camera.global_transform.basis.x.slide(aim.normal)
		if not side_dir.is_zero_approx():
			launch_target_position += side_dir.normalized() * 0.13
	hit_surface_normal = aim.normal
	will_hit_surface = aim.hit
	current_hit_type = aim.hit_type
	if aim.node != null:
		current_target_node = aim.node

		if current_hit_type == "target" and current_target_node.has_method("claim_target"):
			current_target_node.claim_target("right")

	if global_position != launch_target_position:
		look_at(launch_target_position, Vector3.UP)
		rotate_object_local(Vector3.UP, PI)

	if current_hit_type in ["surface", "pullable"]:
		var temp_trans = global_transform
		_align_to_surface(hit_surface_normal)
		var slide_vector = global_transform.basis * Vector3(0, surface_slide_offset, 0)
		global_transform = temp_trans
		
		launch_target_position += slide_vector

		if current_hit_type == "pullable" and current_target_node:
			hit_offset_local = current_target_node.to_local(launch_target_position)
			hit_normal_local = current_target_node.global_transform.basis.inverse() * hit_surface_normal

	launch_duration = max(launch_start_position.distance_to(launch_target_position) / launch_speed, 0.05)

	play_animation("Fire")

	if launch_sounds.size() > 0:
		_play_one_shot(launch_sounds.pick_random())

func start_pulling() -> void:
	if current_state == HandState.ATTACHED and current_hit_type == "pullable" and current_target_node:
		current_state = HandState.PULLING
		if current_hand_node and current_hand_node.name == "PressureHand":
			return
		if current_target_node.has_method("start_pulling"):
			current_target_node.start_pulling("right", _get_pull_target())

	if current_state == HandState.ATTACHED and current_hit_type == "target" and current_target_node:
		current_state = HandState.PULLING
		current_target_node.trigger_pull("right")

func release_grab() -> void:
	if current_hit_type == "target" and current_target_node and is_instance_valid(current_target_node) and "custom_release_sound" in current_target_node and current_target_node.custom_release_sound:
		_play_one_shot(current_target_node.custom_release_sound)
	elif launch_sounds.size() > 0:
		_play_one_shot(release_sounds.pick_random())

	if current_state == HandState.ATTACHED or current_state == HandState.PULLING:
		start_retract()

func _get_aim_target() -> Dictionary:
	var result = {"position": Vector3.ZERO, "normal": Vector3.UP, "hit": false, "hit_type": "surface", "node": null}
	var hit_collider = null

	if item_raycast:
		item_raycast.force_raycast_update()
		if item_raycast.is_colliding():
			var col = item_raycast.get_collider()
			if _is_valid_grab_target(col):
				var is_allowed = true
				if col.has_method("is_hand_allowed"):
					is_allowed = col.is_hand_allowed("right")
				if is_allowed:
					hit_collider = col
					result.hit_type = "target"
					result.node = hit_collider
					result.hit = true

					var marker = col.get("marker") if "marker" in col else null
					var use_marker = col.get("use_marker_for_launch") if "use_marker_for_launch" in col else false

					if marker and use_marker:
						result.position = marker.global_position
					else:
						result.position = item_raycast.get_collision_point()

					result.normal = item_raycast.get_collision_normal()
					return result

	if use_camera_raycast:
		var cam_start = camera.global_position
		var cam_end = cam_start + (-camera.global_transform.basis.z * camera_raycast_range)
		var aim_hit = _cast_through_disabled(camera_raycast.collision_mask, cam_start, cam_end, "right")
		if not aim_hit.is_empty():
			hit_collider = aim_hit.collider
			result.position = aim_hit.position
			result.normal = aim_hit.normal
			result.hit = true

	if hit_collider:
		var pickable = hit_collider if hit_collider is PickableObject else (hit_collider.get_parent() if hit_collider.get_parent() is PickableObject else null)

		if _is_valid_grab_target(hit_collider):
			result.hit_type = "target"
			result.node = hit_collider
		elif is_held:
			result.hit_type = "surface"
			result.node = null
		elif pickable:
			if not _is_pickable_already_held(pickable):
				result.hit_type = "pickable"
				result.node = pickable
			else:
				result.hit_type = "surface"
				result.node = null
		elif hit_collider is PullableObject:
			result.hit_type = "pullable"
			result.node = hit_collider
		else:
			result.hit_type = "surface"
			result.node = hit_collider
		return result

	var look_dir: Vector3 = -camera.global_transform.basis.z
	result.position = camera.global_position + (look_dir * max_range)
	return result

func start_retract() -> void:
	_reset_item_pos_rotation()

	if current_state == HandState.ATTACHED or current_state == HandState.PULLING:
		pickup_target(true)

	if current_target_node and is_instance_valid(current_target_node):
		if current_target_node.get("is_swingable"):
			if player and player.swinging:
				player.swinging = false
				if player.has_node("HookController"):
					player.hook_controller._retract_hook()

		if current_target_node.has_method("stop_pulling"):
			current_target_node.stop_pulling("right")
			if launch_sounds.size() > 0 and not is_held:
				_play_one_shot(release_sounds.pick_random())

		if current_hit_type == "target":
			if "custom_release_sound" in current_target_node and current_target_node.custom_release_sound:
				_play_one_shot(current_target_node.custom_release_sound, 200.0)
			elif launch_sounds.size() > 0 and not is_held:
				_play_one_shot(release_sounds.pick_random())

			if current_target_node.has_method("unclaim_target"):
				current_target_node.unclaim_target("right")
			if current_target_node.has_method("trigger_release"):
				current_target_node.trigger_release("right")

	current_hit_type = "none"
	current_target_node = null
	hit_offset_local = Vector3.ZERO
	hit_normal_local = Vector3.ZERO
	hit_basis_local = Basis()
	hold_to_pull_timer = 0.0
	has_released_after_launch = false
	player.hand_InOut(true, false)
	current_state = HandState.RETRACTING
	
	if cable and cable.rope_points.size() > 2:
		retract_path = cable.rope_points.duplicate()
		retract_path.reverse()
		retract_path.pop_front()
		if retract_path.size() > 0:
			retract_path.pop_back()
	else:
		retract_path.clear()

	play_animation("Reverse")

func _get_held_anim_name() -> String:
	if is_held and is_instance_valid(held_object):
		for child in held_object.get_children():
			if child is GrabTarget and "anim_name" in child and child.anim_name != "":
				return child.anim_name
		if "anim_name" in held_object and held_object.anim_name != "":
			return held_object.anim_name
	return ""

func pickup_target(pick: bool) -> void:
	if pick:
		if not is_instance_valid(current_target_node):
			return

		var pickable: PickableObject = null
		var grab_target: GrabTarget = null

		# Locate PickableObject and its associated GrabTarget
		if current_target_node is GrabTarget:
			grab_target = current_target_node
			if "pickable_object" in current_target_node and current_target_node.get("pickable_object") is PickableObject:
				pickable = current_target_node.get("pickable_object")
			elif current_target_node.get_parent() is PickableObject:
				pickable = current_target_node.get_parent()
		elif current_target_node is PickableObject:
			pickable = current_target_node
			for child in current_target_node.get_children():
				if child is GrabTarget:
					grab_target = child
					break
		elif current_target_node.get_parent() is PickableObject:
			pickable = current_target_node.get_parent()
			for child in pickable.get_children():
				if child is GrabTarget:
					grab_target = child
					break
		if grab_target:
			if grab_target and (not grab_target.is_grabbed or grab_target.current_claiming_hand != "right"):
					return

		if pickable and not _is_pickable_already_held(pickable):
			pickable.pick_up("right", item_pos)
			held_object = pickable
			is_held = true
			var held_anim = _get_held_anim_name()
			if held_anim != "":
				play_animation(held_anim)
	else:
		if is_held and is_instance_valid(held_object):
			held_object.drop()
			held_object = null
			is_held = false
			if launch_sounds.size() > 0:
				_play_one_shot(release_sounds.pick_random())
			play_animation("Retract")

			if current_state == HandState.HOLDING:
				current_state = HandState.IDLE

func _align_to_surface(target_normal: Vector3) -> void:
	var current_scale = global_transform.basis.get_scale()

	# Use world UP as a stable reference (matches what hand_basis.y typically is)
	var reference_dir: Vector3 = Vector3.UP

	# If the surface normal is nearly parallel to UP (floor/ceiling),
	# project camera forward onto the surface plane instead
	if abs(target_normal.dot(Vector3.UP)) > 0.99:
		var cam_fwd: Vector3 = Vector3.FORWARD
		if camera:
			cam_fwd = (-camera.global_transform.basis.z).normalized()
		reference_dir = (cam_fwd - target_normal * cam_fwd.dot(target_normal)).normalized()
		if reference_dir.length_squared() < 0.001:
			reference_dir = Vector3.RIGHT

	var right_axis = target_normal.cross(reference_dir).normalized()
	if right_axis.is_zero_approx():
		right_axis = Vector3.RIGHT

	var forward_axis = right_axis.cross(target_normal).normalized()
	var result = Basis(right_axis, target_normal, forward_axis)

	global_transform.basis = result.orthonormalized().scaled(current_scale)
	rotate_object_local(Vector3.RIGHT, PI / 2.0)

func _apply_item_pos_surface_rotation() -> void:
	if not is_item_pos_rotated:
		item_pos.rotation.x = initial_item_pos_rotation.x + deg_to_rad(surface_hit_item_rotation_deg)
		is_item_pos_rotated = true

func _reset_item_pos_rotation() -> void:
	if is_item_pos_rotated:
		item_pos.rotation = initial_item_pos_rotation
		is_item_pos_rotated = false

func _play_one_shot(stream: AudioStream, vol: float = 0.0) -> void:
	if not stream:
		return
	var p = AudioStreamPlayer3D.new()
	p.stream = stream
	p.volume_db = vol
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

func _play_grab_sound(hand_grab: bool) -> void:
	if not hand_grab and grab_sounds.size() > 0:
		_play_one_shot(grab_sounds.pick_random())
	elif hand_grab:
		_play_one_shot(hand_grab_audio)


func _on_timer_timeout() -> void:
	switching = false
	$"../../../RightTubeIK".influence = 1.0

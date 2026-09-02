extends Node3D

enum HandState { IDLE, LAUNCHING, ATTACHED, PULLING, RETRACTING, HOLDING }
var current_state: HandState = HandState.IDLE

var max_range = 30.0
var launch_speed: float = 25.0
var retract_speed: float = 30.0
var stick_time: float = 0.35
var surface_push_offset: float = 0.015
var initial_scale: Vector3 = self.scale
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
@export var grab_sounds: Array[AudioStream]
@export var release_sounds: Array[AudioStream]

@onready var hand_pos: Node3D = $".."
@onready var player: CharacterBody3D = $"../../../../../../.."
@onready var retract_audio_player: AudioStreamPlayer3D = $"../../LeftHandAudio"

@onready var raycast: RayCast3D = $RayCast3D
@onready var finger_rays: Node3D = $FigerRays
@onready var cable: CablePhysics = $"../CablePhysics"
@onready var sk_left_hand: Node3D = $SK_LeftHand
@onready var anim_tree: AnimationTree = $AnimationTree
@onready var item_pos: Node3D = $ItemPos

@onready var grabpack: Node3D = $"../../../../../.."

@onready var camera: Camera3D = $"../../../../../../../Neck/Camera3D"
@onready var camera_raycast: RayCast3D = $"../../../../../../../Neck/Camera3D/RayCast3D"
@onready var item_raycast: RayCast3D = $"../../../../../../../Neck/Camera3D/ItemRaycast"

@onready var lean_modifier: BoneMultiModifier = $"../../../LeftHandLean"
@onready var left_tube: JacobianIK3D = $"../../../LeftTubeIK"

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

func _process(delta: float) -> void:
	if current_state != HandState.RETRACTING and current_state != HandState.HOLDING:
		if current_state != HandState.IDLE:
			await get_tree().create_timer(0.05).timeout
			lean_modifier.lookat_influence = lerp(lean_modifier.lookat_influence, 1.0, 12.0 * delta)
			left_tube.active = true
		else:
			lean_modifier.lookat_influence = lerp(lean_modifier.lookat_influence, 0.0, 12.0 * delta)
			left_tube.active = false
	else:
		lean_modifier.lookat_influence = lerp(lean_modifier.lookat_influence, 0.0, 12.0 * delta)
		left_tube.active = false

	if current_state == HandState.ATTACHED or current_state == HandState.PULLING:
		if has_node("FigerRays/Finger2") and not $FigerRays/Finger2.is_colliding():
			if has_node("FigerRays/Finger3") and not $FigerRays/Finger3.is_colliding():
				play_animation("SraightEdge" if has_node("FigerRays/Finger1") and not $FigerRays/Finger1.is_colliding() else "HandleHalf")
			else:
				play_animation("FingerTips")
		else:
			play_animation("Straight")

	if current_state == HandState.ATTACHED or current_state == HandState.PULLING:
		if not is_held:
			if current_hit_type == "pullable":
				var ray1_colliding = $FigerRays/RotationRay2.is_colliding()
				var ray2_colliding = $FigerRays/RotationRay1.is_colliding()

				var rot_change: float = 0.0
				if not ray1_colliding and ray2_colliding:
					rot_change = -90.0 * delta
				elif not ray2_colliding and ray1_colliding:
					rot_change = 90.0 * delta

				if rot_change != 0.0:
					hit_basis_local = hit_basis_local * Basis(Vector3.FORWARD, rot_change)
			elif current_hit_type == "surface":
				var ray1_colliding = $FigerRays/RotationRay1.is_colliding()
				var ray2_colliding = $FigerRays/RotationRay2.is_colliding()

				var rot_change: float = 0.0
				if not ray1_colliding and ray2_colliding:
					rot_change = -20.0 * delta
				elif not ray2_colliding and ray1_colliding:
					rot_change = 20.0 * delta

				if rot_change != 0.0:
					rotation.z += rot_change

func _physics_process(delta: float) -> void:
	var target_needs_manual_retract: bool = _target_requires_manual_retract()
	if current_state == HandState.IDLE:
		_reset_item_pos_rotation()
		if Input.is_action_just_pressed("left_hand"):
			launch()
	elif not player.is_grabpack_lowered:
		if current_state == HandState.HOLDING:
			if Input.is_action_just_pressed("left_hand"):
				hold_to_pull_timer = 0.0

			if Input.is_action_pressed("left_hand"):
				hold_to_pull_timer += delta
				if hold_to_pull_timer >= 0.75:
					pickup_target(false)
					hold_to_pull_timer = 0.0
			elif Input.is_action_just_pressed("drop_item"):
				pickup_target(false)
				hold_to_pull_timer = 0.0
			elif Input.is_action_just_released("left_hand"):
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
	
	if not Input.is_action_pressed("left_hand"):
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

	if has_released_after_launch and Input.is_action_just_pressed("left_hand"):
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
			top_level = false
			position = Vector3.ZERO
			rotation = Vector3.ZERO
			scale = initial_scale
			_reset_item_pos_rotation()
			
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
			launch_elapsed += delta
			var t: float = 1.0
			if launch_duration > 0.0:
				t = clamp(launch_elapsed / launch_duration, 0.0, 1.0)

			var ease_t = 1.0 - pow(1.0 - t, 3.0)
			var next_position: Vector3 = launch_start_position.lerp(launch_target_position, ease_t)
			if global_position.distance_squared_to(launch_target_position) > 0.01:
				var dir = (launch_target_position - global_position).normalized()
				if not dir.is_zero_approx():
					var up_dir = Vector3.UP
					if abs(dir.y) > 0.99:
						up_dir = Vector3.FORWARD
						
					var target_basis = Basis.looking_at(dir, up_dir)
					target_basis = target_basis.rotated(target_basis.y, PI)
					
					var current_quat = global_transform.basis.get_rotation_quaternion()
					var target_quat = target_basis.get_rotation_quaternion()
					
					var new_basis = Basis(current_quat.slerp(target_quat, delta * 25.0))
					global_transform.basis = new_basis.scaled(scale)

			if global_position.distance_squared_to(next_position) > 0.0001:
				var hit = _cast_through_disabled(camera_collision_mask, global_position, next_position, "left")
				if hit:
					var col = hit.collider
					var pickable = col if col is PickableObject else (col.get_parent() if col.get_parent() is PickableObject else null)

					if _is_valid_grab_target(col):
						var is_allowed = true
						if col.has_method("is_hand_allowed"):
							is_allowed = col.is_hand_allowed("left")
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
						current_target_node.trigger_grab("left")
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
						if Input.is_action_just_pressed("left_hand"):
							hold_to_pull_timer = 0.0

						if Input.is_action_pressed("left_hand"):
							hold_to_pull_timer += delta
							if hold_to_pull_timer >= 0.15:
								start_pulling()
						elif Input.is_action_just_released("left_hand"):
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
					if Input.is_action_just_pressed("left_hand"):
						hold_to_pull_timer = 0.0

					if Input.is_action_pressed("left_hand"):
						hold_to_pull_timer += delta
						if hold_to_pull_timer >= 0.15:
							start_pulling()
					elif Input.is_action_just_released("left_hand"):
						if hold_to_pull_timer > 0.0 and hold_to_pull_timer < 0.15:
							if current_target_node is PullableObject:
								var yank_dir = (pull_target - current_target_node.global_position).normalized()
								current_target_node.apply_central_impulse(yank_dir * 6.0 + Vector3.UP * 1.5)
							start_retract()
						hold_to_pull_timer = 0.0
			else:
				stick_timer -= delta
				if stick_timer <= 0.0:
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
						current_target_node.update_pull_target("left", _get_pull_target())

		HandState.RETRACTING:
			_reset_item_pos_rotation()
			var target_position: Vector3 = retract_path[0] if retract_path.size() > 0 else hand_pos.global_position

			var dynamic_speed = retract_speed * clamp(global_position.distance_to(target_position) * 0.4, 0.8, 2.5)
			var step = dynamic_speed * delta
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
				exclusions.append(col.get_rid())
				continue
		else:
			return hit

	return {}

func _is_valid_grab_target(col: Node) -> bool:
	if not (col is GrabTarget):
		return false
	if col.is_in_group("BatteryHolder"):
		return is_held and is_instance_valid(held_object) and held_object.is_in_group("Battery")
	
	return not is_held

func _is_pickable_already_held(pickable: Node3D) -> bool:
	if not is_instance_valid(pickable):
		return false
	if "is_held" in pickable and pickable.is_held:
		return true
	var group_name = "LeftHand" if name != "LeftHand" else "RightHand"
	var other_hand = get_tree().get_first_node_in_group(group_name)
	if other_hand and "held_object" in other_hand and other_hand.held_object == pickable:
		return true
	return false

func _is_target_busy(target_node: Node) -> bool:
	var right_hand = get_tree().get_first_node_in_group("RightHand")
	if right_hand and is_instance_valid(right_hand):
		if right_hand.held_object == target_node or right_hand.current_target_node == target_node:
			return true
	return false

func _target_requires_manual_retract() -> bool:
	if current_target_node and is_instance_valid(current_target_node) and "require_manual_retract_left_hand" in current_target_node:
		return current_target_node.require_manual_retract_left_hand
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

func cable_sound(on: bool):
	if on:
		if retract_loop_audio and not retract_audio_player.playing:
			retract_audio_player.stream = retract_loop_audio
			retract_audio_player.play()
	else:
		if retract_audio_player.playing:
			retract_audio_player.stop()

func launch() -> void:
	if player.is_grabpack_lowered:
		return
	if current_state != HandState.IDLE and current_state != HandState.HOLDING:
		return
	cable.is_active = true
	player.hand_InOut(false, true)
	has_released_after_launch = false

	top_level = true

	current_hit_type = "surface"
	current_target_node = null
	hit_offset_local = Vector3.ZERO
	hit_normal_local = Vector3.ZERO
	hit_basis_local = Basis()
	hold_to_pull_timer = 0.0
	current_state = HandState.LAUNCHING
	launch_start_position = hand_pos.global_position
	
	global_position = launch_start_position
	scale = initial_scale
	launch_elapsed = 0.0

	var aim: Dictionary = _get_aim_target()
	launch_target_position = aim.position
	if camera and aim.hit_type != "target" and aim.hit:
		var side_dir = (-camera.global_transform.basis.x).slide(aim.normal)
		if not side_dir.is_zero_approx():
			launch_target_position += side_dir.normalized() * 0.13
	hit_surface_normal = aim.normal
	will_hit_surface = aim.hit
	current_hit_type = aim.hit_type
	if aim.node != null:
		current_target_node = aim.node

		if current_hit_type == "target" and current_target_node.has_method("claim_target"):
			current_target_node.claim_target("left")

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
		_play_one_shot(launch_sounds.pick_random(), 100.0)

func start_pulling() -> void:
	if current_state == HandState.ATTACHED and current_hit_type == "pullable" and current_target_node:
		current_state = HandState.PULLING
		if current_target_node.has_method("start_pulling"):
			current_target_node.start_pulling("left", _get_pull_target())

	if current_state == HandState.ATTACHED and current_hit_type == "target" and current_target_node:
		current_state = HandState.PULLING
		current_target_node.trigger_pull("left")

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
					is_allowed = col.is_hand_allowed("left")
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
		var aim_hit = _cast_through_disabled(camera_raycast.collision_mask, cam_start, cam_end, "left")
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
	
	if current_target_node and is_instance_valid(current_target_node):
		if current_target_node.has_method("stop_pulling"):
			current_target_node.stop_pulling("left")
			if launch_sounds.size() > 0 and not is_held:
				_play_one_shot(release_sounds.pick_random())

		if current_hit_type == "target":
			if "custom_release_sound" in current_target_node and current_target_node.custom_release_sound:
				_play_one_shot(current_target_node.custom_release_sound, 200.0)
			elif launch_sounds.size() > 0 and not is_held:
				_play_one_shot(release_sounds.pick_random())

			if current_target_node.has_method("unclaim_target"):
				current_target_node.unclaim_target("left")
			if current_target_node.has_method("trigger_release"):
				current_target_node.trigger_release("left")

	current_hit_type = "none"
	current_target_node = null
	hit_offset_local = Vector3.ZERO
	hit_normal_local = Vector3.ZERO
	hit_basis_local = Basis()
	hold_to_pull_timer = 0.0
	has_released_after_launch = false
	player.hand_InOut(false, false)
	current_state = HandState.RETRACTING
	
	if cable and cable.rope_points.size() > 2:
		retract_path = cable.rope_points.duplicate()
		retract_path.reverse()
		retract_path.pop_front()
		if retract_path.size() > 0:
			retract_path.pop_back()
	else:
		retract_path.clear()
		
	play_animation("Retract")

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
			if not grab_target.is_grabbed or grab_target.current_claiming_hand != "left":
				return

		if pickable and not _is_pickable_already_held(pickable):
			pickable.pick_up("left", item_pos)
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
	var reference_dir: Vector3 = Vector3.UP

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
	if item_pos and not is_item_pos_rotated:
		item_pos.rotation.x = initial_item_pos_rotation.x + deg_to_rad(surface_hit_item_rotation_deg)
		is_item_pos_rotated = true

func _reset_item_pos_rotation() -> void:
	if item_pos and is_item_pos_rotated:
		item_pos.rotation = initial_item_pos_rotation
		is_item_pos_rotated = false

func play_animation(anim_name: String) -> void:
	if is_held:
		if anim_name in ["Retract", "Reverse", "Straight"]:
			return
		var held_anim = _get_held_anim_name()
		if held_anim != "":
			anim_name = held_anim

	if anim_tree and anim_name != "":
		anim_tree.set("parameters/Transition/transition_request", anim_name)

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

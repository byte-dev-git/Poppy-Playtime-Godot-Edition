extends CharacterBody3D

@onready var neck: Node3D = $Neck
@onready var camera: Camera3D = $Neck/Camera3D
@onready var grabpack: Node3D = $Grabpack
@onready var standing_collision: CollisionShape3D = $StandingCollision
@onready var crouch_collision: CollisionShape3D = $CrouchCollision
@onready var crouch_cast: RayCast3D = $RayCast3D
@onready var anim_tree: AnimationTree = $Grabpack/SK_FirstPersonPlayer_Grabpack/AnimationTree
@onready var grabpack_bone: BoneAttachment3D = $Grabpack/SK_FirstPersonPlayer_Grabpack/SK_FirstPersonPlayer_Grabpack/Skeleton3D/CameraBone_JNT
@onready var hook_controller: HookController = $HookController
@onready var left_hand = $Grabpack/LeftHand
@onready var right_hand: Node3D = $Grabpack/RightHand
@onready var cable_manager: CableManager = $CableManager
@onready var sound_manager: SoundManager = $SoundManager

@export_category("Settings")
@export var movable: bool = true
@export var enable_camera_animation: bool = true

@export_group("Movement Physics")
var speed: float = 10.0
var normal_speed: float = 2.92
var sprint_speed: float = 6.01
var crouching_speed: float = 1.49
var squeeze_speed: float = 1.0
var speed_lerp: float = 12.0
var acceleration: float = 40.24
var decelleration: float = 50.0

var jump_height: float = 0.6
var gravity: float = 9.0
var camera_sens: float = 1.35
var camera_smooth_speed: float = 15.0

var player_height: float = 1.7
var crouch_depth: float = 0.85
var crouch_speed: float = 3.5
var sway_speed: float = 25.0

var jumping: bool = false
var crouched: bool = false
var is_sprinting: bool = false
var is_squeezing: bool = false
var mouse_captured: bool = false
var is_grabpack_lowered: bool = false 

var was_crouched: bool = false 
var was_on_floor: bool = true 
var was_moving: bool = false

var move_dir: Vector2 
var look_dir: Vector2 
var walk_vel: Vector3 
var grav_vel: Vector3 
var jump_vel: Vector3 
var external_velocity: Vector3 = Vector3.ZERO

var target_rotation: Vector2 
var grabpack_blend_target: float = 0.0
var grabpack_timer: float = 0.0 
var grabpack_cooldown: float = 0.5

var swinging: bool = false
var swinging_point: Vector3 = Vector3.ZERO
var swinging_time: float = 0.0

func _ready() -> void:
	if has_node("/root/Manager"):
		get_node("/root/Manager").call("start")
	capture_mouse(true, false)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			capture_mouse(!mouse_captured, false)
			return

	if not movable: return

	if event is InputEventMouseMotion and mouse_captured:
		look_dir = event.relative * 0.001
		_rotate_camera()
		
	if Input.is_action_just_pressed("jump") and not crouched:
		jumping = true

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_L: lower_grabpack()
		elif event.keycode == KEY_R: raise_grabpack()
		elif event.keycode == KEY_T: lower_raise_grabpack()
		elif event.keycode == KEY_V: enable_camera_animation = !enable_camera_animation

func _process(delta: float) -> void:
	neck.rotation.x = lerp_angle(neck.rotation.x, target_rotation.x, camera_smooth_speed * delta)
	neck.rotation.y = lerp_angle(neck.rotation.y, target_rotation.y, camera_smooth_speed * delta)
	grabpack.rotation.x = lerp_angle(grabpack.rotation.x, neck.rotation.x, sway_speed * delta)
	grabpack.rotation.y = lerp_angle(grabpack.rotation.y, neck.rotation.y, sway_speed * delta)
	
	if enable_camera_animation and grabpack_bone:
		camera.quaternion = grabpack_bone.quaternion
	else:
		camera.quaternion = camera.quaternion.slerp(Quaternion(), 10.0 * delta)

func _physics_process(delta: float) -> void:
	if not movable or not mouse_captured:
		walk_vel = walk_vel.move_toward(Vector3.ZERO, decelleration * delta)
		velocity = walk_vel + _gravity(delta)
		move_and_slide()
		_update_animations(delta)
		return

	# Handle Crouch
	var crouch_request: bool = Input.is_action_pressed("crouch") or crouch_cast.is_colliding()
	crouched = crouch_request
	if grabpack_timer > 0.0: grabpack_timer -= delta
	if crouched:
		standing_collision.disabled = true
		crouch_collision.disabled = false
		neck.position.y = move_toward(neck.position.y, crouch_depth, crouch_speed * delta)
	else:
		standing_collision.disabled = false
		crouch_collision.disabled = true
		neck.position.y = move_toward(neck.position.y, player_height, crouch_speed * delta)
		
	grabpack.position.y = neck.position.y
	is_sprinting = Input.is_action_pressed("sprint")
	
	# Speed Interpolation
	if crouched: speed = lerp(speed, crouching_speed, speed_lerp * delta)
	elif is_squeezing: speed = lerp(speed, squeeze_speed, speed_lerp * delta)
	elif is_sprinting: speed = lerp(speed, sprint_speed, speed_lerp * delta)
	else: speed = lerp(speed, normal_speed, speed_lerp * delta)

	# Movement & Swinging State
	if not swinging: 
		swinging_time = 0.0
		velocity = _walk(delta) + _gravity(delta) + _jump(delta)
		velocity += external_velocity
		external_velocity = external_velocity.move_toward(Vector3.ZERO, 15.0 * delta)
	elif is_on_floor():
		velocity = _walk(delta) + _gravity(delta) + _jump(delta)
	else:
		if has_node("SwingPlayer") and not $SwingPlayer.playing: 
			$SwingPlayer.play()
		swinging_time += delta
		var air_control = _walk(delta) * 0.2
		velocity += Vector3(air_control.x, 0, air_control.z)

	# Restrict outward velocity before moving to eliminate physics jitter
	if cable_manager:
		cable_manager.apply_player_tension(self)

	move_and_slide()
	_update_animations(delta)

func _rotate_camera() -> void:
	target_rotation.y -= look_dir.x * camera_sens
	target_rotation.x = clamp(target_rotation.x - look_dir.y * camera_sens, -1.5, 1.5)

func _walk(delta: float) -> Vector3:
	move_dir = Input.get_vector("left", "right", "forward", "backward")
	var _forward: Vector3 = neck.global_transform.basis * Vector3(move_dir.x, 0, move_dir.y)
	var walk_dir: Vector3 = Vector3(_forward.x, 0, _forward.z).normalized()
	var target_accel = acceleration if move_dir != Vector2.ZERO else decelleration
	walk_vel = walk_vel.move_toward(walk_dir * speed * move_dir.length(), target_accel * delta)
	return walk_vel

func _gravity(delta: float) -> Vector3:
	grav_vel = Vector3.ZERO if is_on_floor() else grav_vel.move_toward(Vector3(0, velocity.y - gravity, 0), gravity * delta)
	return grav_vel

func _jump(delta: float) -> Vector3:
	if jumping:
		if is_on_floor() and not crouch_cast.is_colliding():
			jump_vel = Vector3(0, sqrt(4 * jump_height * gravity), 0)
		jumping = false
		return jump_vel
		
	jump_vel = Vector3.ZERO if is_on_floor() else jump_vel.move_toward(Vector3.ZERO, gravity * delta)
	return jump_vel

func capture_mouse(capture_mode: bool, radial_menu: bool) -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if capture_mode else Input.MOUSE_MODE_VISIBLE)
	mouse_captured = capture_mode
	
	if radial_menu: return
	if capture_mode:
		Engine.time_scale = 1.0
	else: Engine.time_scale = 0.0

func lower_grabpack() -> void:
	if grabpack_timer > 0.0 or is_grabpack_lowered: return
	var playback = anim_tree.get("parameters/GrabpackSM/playback")
	if playback:
		_play_one_shot(sound_manager.switch_sidle_sound.pick_random())
		playback.travel("Lower")
	is_grabpack_lowered = true
	grabpack_blend_target = 1.0 
	grabpack_timer = grabpack_cooldown

func raise_grabpack() -> void:
	if grabpack_timer > 0.0 or not is_grabpack_lowered: return
	var playback = anim_tree.get("parameters/GrabpackSM/playback")
	if playback:
		_play_one_shot(sound_manager.switch_sidle_sound.pick_random())
		playback.travel("Raise")
	is_grabpack_lowered = false
	grabpack_blend_target = 1.0 
	grabpack_timer = grabpack_cooldown
	await get_tree().create_timer(0.5).timeout
	if playback: playback.travel("Empty")
	grabpack_blend_target = 0.0

func lower_raise_grabpack() -> void:
	if is_grabpack_lowered or grabpack_timer > 0.0: return
	lower_grabpack()
	await get_tree().create_timer(0.7).timeout
	if $Grabpack/SK_FirstPersonPlayer_Grabpack/SK_FirstPersonPlayer_Grabpack/Skeleton3D/SK_FirstPersonPlayer_Grabpack_02.visible:
		$Grabpack/SK_FirstPersonPlayer_Grabpack/SK_FirstPersonPlayer_Grabpack/Skeleton3D/SK_FirstPersonPlayer_Grabpack_02.visible = false
		$Grabpack/SK_FirstPersonPlayer_Grabpack/SK_FirstPersonPlayer_Grabpack/Skeleton3D/SK_FirstPersonPlayer_Grabpack3.visible = true
	else:
		$Grabpack/SK_FirstPersonPlayer_Grabpack/SK_FirstPersonPlayer_Grabpack/Skeleton3D/SK_FirstPersonPlayer_Grabpack_02.visible = true
		$Grabpack/SK_FirstPersonPlayer_Grabpack/SK_FirstPersonPlayer_Grabpack/Skeleton3D/SK_FirstPersonPlayer_Grabpack3.visible = false
	raise_grabpack()

func _update_animations(delta: float) -> void:
	if not anim_tree: return
	var horizontal_velocity = Vector2(velocity.x, velocity.z)
	var is_moving = horizontal_velocity.length() > 0.1 and is_on_floor()
	var target_walk_blend = 1.0 if is_moving else 0.0
	var current_walk_blend = anim_tree.get("parameters/IdleWalk/blend_amount")
	if current_walk_blend == null: current_walk_blend = 0.0
	anim_tree.set("parameters/IdleWalk/blend_amount", lerp(current_walk_blend, target_walk_blend, 10.0 * delta))
	
	if is_moving:
		var speed_scale: float = (speed / normal_speed) if crouched else (1.0 + ((speed - normal_speed) * 0.5))
		anim_tree.set("parameters/WalkSpeed/scale", max(0.5, speed_scale))
		
	if was_moving and not is_moving:
		anim_tree.set("parameters/WalkToStop/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	was_moving = is_moving
	
	if crouched != was_crouched:
		anim_tree.set("parameters/CrouchEnter/request" if crouched else "parameters/CrouchExit/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	was_crouched = crouched
	
	var target_tilt = Vector2(move_dir.x, -move_dir.y)
	var current_tilt = anim_tree.get("parameters/Tilt/blend_position")
	if current_tilt == null: current_tilt = Vector2.ZERO
	anim_tree.set("parameters/Tilt/blend_position", current_tilt.lerp(target_tilt, 5.0 * delta))
	
	var target_fall_blend = 1.0 if not is_on_floor() else 0.0
	var current_fall_blend = anim_tree.get("parameters/Falling/blend_amount")
	if current_fall_blend == null: current_fall_blend = 0.0
	anim_tree.set("parameters/Falling/blend_amount", lerp(current_fall_blend, target_fall_blend, 5.0 * delta))
	
	if not is_on_floor() and was_on_floor and velocity.y > 0:
		anim_tree.set("parameters/Jump/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	elif is_on_floor() and not was_on_floor:
		anim_tree.set("parameters/Land/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		
	was_on_floor = is_on_floor()
	
	var current_grabpack_blend = anim_tree.get("parameters/GrabpackToggle/blend_amount")
	if current_grabpack_blend == null: current_grabpack_blend = 0.0
	anim_tree.set("parameters/GrabpackToggle/blend_amount", lerp(current_grabpack_blend, grabpack_blend_target, 10.0 * delta))

func hand_left(hand: bool):
	anim_tree.set("parameters/ShootOutLeft/request" if hand else "parameters/ShootInLeft/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func hand_right(hand: bool):
	anim_tree.set("parameters/ShootOutRight/request" if hand else "parameters/ShootInRight/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func apply_swing(anchor: Vector3, max_allowed_radius: float, _delta: float) -> void:
	swinging = true
	swinging_point = anchor
	
	var to_player = global_position - anchor
	var dist = to_player.length()
	
	if dist > max_allowed_radius and max_allowed_radius > 0.0:
		var dir_from_anchor = to_player / dist
		global_position = anchor + (dir_from_anchor * max_allowed_radius)
		
		if velocity.dot(dir_from_anchor) > 0:
			velocity -= velocity.project(dir_from_anchor)
		if walk_vel.dot(dir_from_anchor) > 0:
			walk_vel -= walk_vel.project(dir_from_anchor)

func _play_one_shot(stream: AudioStream, vol: float = 0.0) -> void:
	if not stream: return
	var p = AudioStreamPlayer3D.new()
	p.stream = stream
	p.volume_db = vol
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

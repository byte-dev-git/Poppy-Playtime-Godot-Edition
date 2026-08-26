extends Node3D

@export var min_push_force: float = 0.0
@export var max_push_force: float = 25.0
@export var charge_speed: float = 4.0

# Sound Node References - Assign these in the Inspector!
@export var building_sound: AudioStreamPlayer
@export var release_partial_sound: AudioStreamPlayer
@export var release_full_sound: AudioStreamPlayer

@onready var raycast: RayCast3D = $RayCast3D
@onready var progress_bar: TextureProgressBar = $Crosshair/PressureHandProgress

var current_power: float = 0.0
var was_pulling: bool = false
var main_hand_script: Node3D = null
var cached_target: RigidBody3D = null

func _ready() -> void:
	main_hand_script = get_parent().get_parent()
	if progress_bar:
		progress_bar.visible = false

func _physics_process(delta: float) -> void:
	if not main_hand_script: 
		return
		
	# --- NEW LOGIC: Verify we have a valid Pushable target ---
	var has_valid_target: bool = false
	
	# Priority 1: Check Raycast
	raycast.force_raycast_update()
	if raycast.is_colliding():
		var collider = raycast.get_collider()
		if collider is RigidBody3D and collider.is_in_group("Pushable"):
			has_valid_target = true
			
	# Priority 2: Check current_target_node fallback
	if not has_valid_target and main_hand_script.current_target_node != null:
		if main_hand_script.current_target_node is RigidBody3D and main_hand_script.current_target_node.is_in_group("Pushable"):
			has_valid_target = true
	# ---------------------------------------------------------
	
	# Only allow pulling if state is 3 AND we are aiming at a Pushable object
	var is_pulling: bool = (main_hand_script.current_state == 3) and has_valid_target
	
	if is_pulling:
		if progress_bar:
			progress_bar.visible = true
			
		if not was_pulling:
			was_pulling = true
			
			# --- SOUND LOGIC: Start Building Pressure ---
			if building_sound and not building_sound.playing:
				building_sound.play()
			
		current_power += (max_push_force - min_push_force) * (delta / charge_speed)
		current_power = clamp(current_power, min_push_force, max_push_force)
		
		var charge_percentage: float = ((current_power - min_push_force) / (max_push_force - min_push_force)) * 150.0
		if progress_bar:
			progress_bar.value = charge_percentage
		
		if main_hand_script.current_target_node is RigidBody3D:
			cached_target = main_hand_script.current_target_node
			
	else: 
		if progress_bar:
			progress_bar.visible = false
			
		if was_pulling:
			was_pulling = false
			
			# --- SOUND LOGIC: Stop Building Pressure ---
			if building_sound:
				building_sound.stop()
			
			# --- SOUND LOGIC: Release/Launch ---
			if current_power >= max_push_force:
				# Fired at max pressure
				if release_full_sound:
					release_full_sound.play()
			elif current_power > min_push_force:
				# Fired before reaching max pressure (only if we built some power)
				if release_partial_sound:
					release_partial_sound.play()
			
			execute_push()
			
			# Reset variables
			current_power = 0.0
			cached_target = null
			if progress_bar:
				progress_bar.value = 0.0

func execute_push() -> void:
	var target: RigidBody3D = null
	
	# Priority 1: Check Raycast
	raycast.force_raycast_update()
	if raycast.is_colliding() and raycast.get_collider() is RigidBody3D:
		target = raycast.get_collider() as RigidBody3D
	# Priority 2: Check Cache
	elif cached_target != null:
		target = cached_target

	if target and target.is_in_group("Pushable"):
		var push_direction: Vector3 = (raycast.global_transform.basis * raycast.target_position).normalized()
		var final_force: float = current_power * target.mass
		
		# Apply the blast!
		target.apply_central_impulse(push_direction * final_force)

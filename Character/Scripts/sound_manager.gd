extends Node
class_name SoundManager

@export_category("References")
## The CharacterBody3D player node.
@export var player: CharacterBody3D
## A RayCast3D attached to the player aiming straight down at the floor.
@export var floor_raycast: RayCast3D 

@export_category("Action Sounds (No Variants)")
@export var crouch_uncrouch_sounds: Array[AudioStream]
@export var jump_sounds: Array[AudioStream]
@export var fall_sound: AudioStream
@export var switch_sidle_sound: Array[AudioStream]
@export var flashlight_on: Array[AudioStream]
@export var flashlight_off: AudioStream
@export var flashlight_glowby: Array[AudioStream]

@export_category("Step Distance Thresholds")
@export var walk_step_threshold: float = 2.5
@export var sprint_step_threshold: float = 2.0
@export var crouch_step_threshold: float = 1.8

@export_group("Concrete Sounds")
@export var walk_concrete: Array[AudioStream]
@export var run_concrete: Array[AudioStream]
@export var crouch_walk_concrete: Array[AudioStream]
@export var land_concrete: Array[AudioStream]

@export_group("Glass Sounds")
@export var walk_glass: Array[AudioStream]
@export var run_glass: Array[AudioStream]
@export var crouch_walk_glass: Array[AudioStream]
@export var land_glass: Array[AudioStream]

@export_group("Metal Sounds")
@export var walk_metal: Array[AudioStream]
@export var run_metal: Array[AudioStream]
@export var crouch_walk_metal: Array[AudioStream]
@export var land_metal: Array[AudioStream]

@export_group("Metal Grate Sounds")
@export var walk_metal_grate: Array[AudioStream]
@export var run_metal_grate: Array[AudioStream]
@export var crouch_walk_metal_grate: Array[AudioStream]
@export var land_metal_grate: Array[AudioStream]

@export_group("Carpet Sounds")
@export var walk_carpet: Array[AudioStream]
@export var run_carpet: Array[AudioStream]
@export var crouch_walk_carpet: Array[AudioStream]
@export var land_carpet: Array[AudioStream]

@export_group("Vent Sounds")
@export var walk_vent: Array[AudioStream]
@export var run_vent: Array[AudioStream]
@export var crouch_walk_vent: Array[AudioStream]
@export var land_vent: Array[AudioStream]

@export_group("Plastic Sounds")
@export var walk_plastic: Array[AudioStream]
@export var run_plastic: Array[AudioStream]
@export var crouch_walk_plastic: Array[AudioStream]
@export var land_plastic: Array[AudioStream]

@export_group("Wood Sounds")
@export var walk_wood: Array[AudioStream]
@export var run_wood: Array[AudioStream]
@export var crouch_walk_wood: Array[AudioStream]
@export var land_wood: Array[AudioStream]


# Internal Variables
var _step_distance: float = 0.0
var _was_crouched: bool = false
var _was_on_floor: bool = true
var _is_falling_sound_playing: bool = false
var _fall_audio_player: AudioStreamPlayer3D

# History Trackers to prevent repetition
var _last_crouch_sound: AudioStream
var _last_footstep_sound: AudioStream
var _last_jump_sound: AudioStream

func _ready() -> void:
	_fall_audio_player = AudioStreamPlayer3D.new()
	add_child(_fall_audio_player)
	
	if is_instance_valid(player):
		_was_crouched = player.crouched
		_was_on_floor = player.is_on_floor()

func _process(delta: float) -> void:
	if not is_instance_valid(player):
		return

	_handle_state_sounds()
	_handle_footsteps(delta)

func toggle_sound(state_name: String):
	match state_name:
		"SwitchPack":
			_play_one_shot(switch_sidle_sound.pick_random())
		"FlashlightOn":
			_play_one_shot(flashlight_on.pick_random())
		"FlashlightOff":
			_play_one_shot(flashlight_off)
		"ToggleGlowbyFlashlight":
			_play_one_shot(flashlight_glowby.pick_random())

func _handle_state_sounds() -> void:
	# --- CROUCH / UNCROUCH ---
	if player.crouched != _was_crouched:
		var chosen = _get_non_repeating_sound(crouch_uncrouch_sounds, _last_crouch_sound)
		if chosen:
			_play_one_shot(chosen)
			_last_crouch_sound = chosen
		_was_crouched = player.crouched

	# --- JUMP ---
	if not player.is_on_floor() and _was_on_floor and player.velocity.y > 0:
		var chosen = _get_non_repeating_sound(jump_sounds, _last_jump_sound)
		if chosen:
			_play_one_shot(chosen)
			_last_jump_sound = chosen

	# --- LAND ---
	if player.is_on_floor() and not _was_on_floor:
		_play_landing_sound()
		_is_falling_sound_playing = false
		_fall_audio_player.stop()

	# --- FALL ---
	if not player.is_on_floor() and player.velocity.y < -3.0 and not _is_falling_sound_playing:
		if fall_sound:
			_fall_audio_player.stream = fall_sound
			_fall_audio_player.play()
			_is_falling_sound_playing = true

	_was_on_floor = player.is_on_floor()

func _handle_footsteps(delta: float) -> void:
	if not player.is_on_floor():
		_step_distance = 0.0
		return

	var horizontal_velocity = Vector2(player.velocity.x, player.velocity.z)
	var speed_magnitude = horizontal_velocity.length()

	if speed_magnitude > 0.1:
		_step_distance += speed_magnitude * delta

		var current_threshold = walk_step_threshold
		if player.crouched:
			current_threshold = crouch_step_threshold
		elif player.is_sprinting:
			current_threshold = sprint_step_threshold

		if _step_distance >= current_threshold:
			_step_distance = 0.0
			_play_footstep()
	else:
		_step_distance = 0.0

func _play_footstep() -> void:
	var variant_idx = _get_surface_variant_index()
	var variant_name = Footsteps.SoundVariant.keys()[variant_idx].to_lower()
	
	var action_prefix = "walk"
	var pitch_modifier = 1.0
	var pitch_randomness = 0.15 # Wide and organic for a standard walk

	# Determine the prefix based on player state
	if player.crouched:
		action_prefix = "crouch_walk"
		pitch_randomness = 0.1 # Subtle variations
	elif player.is_sprinting:
		action_prefix = "run"
		pitch_modifier = 1.20 # Sped up significantly!
		pitch_randomness = 0.05 # Tighter pitch range for consistent fast steps

	# Dynamically fetch the correct array by string name
	var prop_name = action_prefix + "_" + variant_name
	var sound_array = get(prop_name) as Array
	
	# Fallback Logic: If crouch_walk is empty, slow down the regular walk
	if action_prefix == "crouch_walk" and (sound_array == null or sound_array.is_empty()):
		sound_array = get("walk_" + variant_name) as Array
		pitch_modifier = 0.70 

	if sound_array != null and sound_array.size() > 0:
		var chosen_sound = _get_non_repeating_sound(sound_array, _last_footstep_sound)
		_last_footstep_sound = chosen_sound
		
		# Combine base speed with random variance
		var final_pitch = pitch_modifier + randf_range(-pitch_randomness, pitch_randomness)
		_play_one_shot(chosen_sound, final_pitch)

func _play_landing_sound() -> void:
	var variant_idx = _get_surface_variant_index()
	var variant_name = Footsteps.SoundVariant.keys()[variant_idx].to_lower()
	
	var prop_name = "land_" + variant_name
	var sound_array = get(prop_name) as Array
	
	if sound_array != null and sound_array.size() > 0:
		var chosen_sound = sound_array.pick_random()
		_play_one_shot(chosen_sound, randf_range(0.9, 1.1))

func _get_surface_variant_index() -> int:
	if floor_raycast and floor_raycast.is_colliding():
		var collider = floor_raycast.get_collider()
		if collider:
			for child in collider.get_children():
				if child is Footsteps:
					return child.type 

	return Footsteps.SoundVariant.Concrete

# --- NEW HELPER: Prevents repetitive sounds ---
func _get_non_repeating_sound(sound_array: Array, last_sound: AudioStream) -> AudioStream:
	if sound_array.is_empty():
		return null
	
	# If there's only 1 sound, we have no choice but to repeat it
	if sound_array.size() == 1:
		return sound_array[0]
		
	var chosen_sound = sound_array.pick_random()
	
	# Keep picking until we get a new sound, capping at 10 tries to be safe
	var attempts = 0
	while chosen_sound == last_sound and attempts < 10:
		chosen_sound = sound_array.pick_random()
		attempts += 1
		
	return chosen_sound

func _play_one_shot(stream: AudioStream, pitch_val: float = 1.0) -> void:
	if not stream: return

	var temp_player = AudioStreamPlayer3D.new()
	temp_player.stream = stream
	temp_player.pitch_scale = pitch_val
		
	player.add_child(temp_player)
	temp_player.play()
	
	temp_player.finished.connect(temp_player.queue_free)

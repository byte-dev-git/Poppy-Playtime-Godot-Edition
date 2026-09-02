extends Node3D

enum ElementState { NEUTRAL, HEAT, CHILL, ELECTRIC }
enum HandState { ATTACHED }

@export_category("Particles")
@export var heat_particles: Array[GPUParticles3D]
@export var chill_particles: Array[GPUParticles3D]
@export var electric_particles: Array[GPUParticles3D]

@export_category("Audio Streams")
@export_group("Heat")
@export var heat_attach_sfx: AudioStream
@export var heat_loop_sfx: AudioStream
@export var heat_lose_sfx: AudioStream
@export var heat_impact_sfx: AudioStream

@export_group("Chilled")
@export var chill_attach_sfx: AudioStream
@export var chill_loop_sfx: AudioStream
@export var chill_lose_sfx: AudioStream
@export var chill_impact_sfx: AudioStream

@export_group("Electric")
@export var electric_attach_sfx: AudioStream
@export var electric_loop_sfx: AudioStream
@export var electric_lose_sfx: AudioStream
@export var electric_impact_sfx: AudioStream

var current_state: ElementState = ElementState.NEUTRAL

var mat_uv: ORMMaterial3D 
var mat_emission: ORMMaterial3D

var transition_tween: Tween
var audio_tween: Tween
var current_timer_id: int = 0

var loop_player: AudioStreamPlayer3D
var oneshot_player: AudioStreamPlayer3D
var state_configs = {}

var transition_duration: float = 0.4
var effect_lifetime: float = 10.0

var _was_colliding: bool = false

@onready var raycast: RayCast3D = $RayCast3D
@onready var shape_cast: ShapeCast3D = $ShapeCast3D
@onready var mesh: MeshInstance3D = $SK_ConducitveHand/SK_ConductiveHand/Skeleton3D/SK_ConductiveHand_001

func _ready() -> void:
	_setup_audio_players()
	_populate_configs()
	
	mat_uv = mesh.get_surface_override_material(0) as ORMMaterial3D
	mat_emission = mesh.get_surface_override_material(1) as ORMMaterial3D
	
	if mat_emission:
		mat_emission.emission_enabled = true
	
	current_state = ElementState.NEUTRAL
	_update_particle_emission(ElementState.NEUTRAL)
	_apply_state_instantly(ElementState.NEUTRAL)

func _setup_audio_players() -> void:
	loop_player = AudioStreamPlayer3D.new()
	oneshot_player = AudioStreamPlayer3D.new()
	add_child(loop_player)
	add_child(oneshot_player)

func _populate_configs() -> void:
	state_configs = {
		ElementState.NEUTRAL: {
			"emission_color": Color.BLACK, "emission_energy": 0.0, "id_alpha": 0.0,
			"uv_target": Vector3(1.0, 0.3, 0.0),
			"attach": null, "loop": null, "lose": null, "particles": [], "impact": null
		},
		ElementState.HEAT: {
			"emission_color": Color(1.0, 0.3, 0.0), "emission_energy": 7.0, "id_alpha": 1.0,
			"uv_target": Vector3(1.249, 0.3, 0.0),
			"attach": heat_attach_sfx, "loop": heat_loop_sfx, "lose": heat_lose_sfx, "particles": heat_particles, "impact": heat_impact_sfx
		},
		ElementState.CHILL: {
			"emission_color": Color(0.0, 0.8, 1.0), "emission_energy": 7.0, "id_alpha": 1.0,
			"uv_target": Vector3(1.749, 0.3, 0.0),
			"attach": chill_attach_sfx, "loop": chill_loop_sfx, "lose": chill_lose_sfx, "particles": chill_particles, "impact": chill_impact_sfx
		},
		ElementState.ELECTRIC: {
			"emission_color": Color(0.0, 1.0, 0.082, 1.0), "emission_energy": 7.0, "id_alpha": 1.0,
			"uv_target": Vector3(1.498, 0.3, 0.0),
			"attach": electric_attach_sfx, "loop": electric_loop_sfx, "lose": electric_lose_sfx, "particles": electric_particles, "impact": electric_impact_sfx
		}
	}

func _apply_state_instantly(state: ElementState) -> void:
	var config = state_configs[state]
	if mat_uv: 
		mat_uv.uv1_offset = config["uv_target"]
	if mat_emission:
		mat_emission.emission = config["emission_color"]
		mat_emission.emission_energy_multiplier = config["emission_energy"]
		mat_emission.albedo_color.a = config["id_alpha"]

func change_state(new_state: ElementState) -> void:
	if current_state == new_state: return
	
	var old_state_config = state_configs[current_state]
	var new_state_config = state_configs[new_state]
	current_state = new_state
	
	if transition_tween and transition_tween.is_running():
		transition_tween.kill()
	
	transition_tween = create_tween().set_parallel(true)
	transition_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	if mat_uv:
		transition_tween.tween_property(mat_uv, "uv1_offset", new_state_config["uv_target"], transition_duration)
	if mat_emission:
		transition_tween.tween_property(mat_emission, "emission", new_state_config["emission_color"], transition_duration)
		transition_tween.tween_property(mat_emission, "emission_energy_multiplier", new_state_config["emission_energy"], transition_duration)
		transition_tween.tween_property(mat_emission, "albedo_color:a", new_state_config["id_alpha"], transition_duration)
	
	_update_particle_emission(new_state)
	_handle_audio_transition(old_state_config, new_state_config)
	
	current_timer_id += 1 
	if new_state != ElementState.NEUTRAL:
		_start_countdown(current_timer_id)

func play_impact() -> void:
	var stream = state_configs[current_state]["impact"]
	if stream:
		_play_temp_sound(stream)

func interrupt() -> void:
	if current_state != ElementState.NEUTRAL:
		change_state(ElementState.NEUTRAL)

func _update_particle_emission(active_state: ElementState) -> void:
	for state in state_configs:
		var is_active = (state == active_state)
		for p in state_configs[state]["particles"]:
			if p: p.emitting = is_active

func _handle_audio_transition(old_config: Dictionary, new_config: Dictionary) -> void:
	if old_config["lose"] != null:
		oneshot_player.stream = old_config["lose"]
		oneshot_player.play()
	if new_config["attach"] != null:
		if oneshot_player.playing:
			_play_temp_sound(new_config["attach"])
		else:
			oneshot_player.stream = new_config["attach"]
			oneshot_player.play()
	if audio_tween and audio_tween.is_running():
		audio_tween.kill()
	audio_tween = create_tween()
	if new_config["loop"] != null:
		loop_player.stream = new_config["loop"]
		loop_player.volume_db = -40.0
		loop_player.play()
		audio_tween.tween_property(loop_player, "volume_db", 0.0, transition_duration)
	else:
		audio_tween.tween_property(loop_player, "volume_db", -40.0, transition_duration)
		audio_tween.tween_callback(loop_player.stop)

func _play_temp_sound(stream: AudioStream) -> void:
	var temp_player = AudioStreamPlayer3D.new()
	temp_player.stream = stream
	add_child(temp_player)
	temp_player.play()
	temp_player.finished.connect(temp_player.queue_free)

func _start_countdown(id_to_check: int) -> void:
	await get_tree().create_timer(effect_lifetime).timeout
	if id_to_check == current_timer_id and current_state != ElementState.NEUTRAL:
		change_state(ElementState.NEUTRAL)

@tool
extends StaticBody3D

enum ElementState { NEUTRAL, HEAT, CHILL, ELECTRIC }
enum HandState { IDLE, RETRACTING, HOLDING }
enum PanelShape { FORM_A, FORM_B, FORM_C }

@export var panel_type: ElementState = ElementState.NEUTRAL:
	set(value):
		panel_type = value
		if is_node_ready():
			apply_state()

@export var panel_shape: PanelShape = PanelShape.FORM_C:
	set(value):
		panel_shape = value
		if is_node_ready():
			_update_shape()

var icon_mesh: MeshInstance3D:
	set(value):
		icon_mesh = value
		if is_node_ready():
			_init_materials()
			apply_state()

var panel_meshes: Array[MeshInstance3D] = []
var panel_collisions: Array[Node3D] = []
var heat_particles: Array[GPUParticles3D] = []
var chill_particles: Array[GPUParticles3D] = []
var electric_particles: Array[GPUParticles3D] = []

var emission_surface_index: int = 2:
	set(value):
		emission_surface_index = value
		if is_node_ready():
			_init_materials()
			apply_state()

@onready var heat_audio: AudioStreamPlayer3D = $SwSfxConductiveHeatPanelLoop
@onready var chill_audio: AudioStreamPlayer3D = $SwSfxConductiveChilledPanelLoop
@onready var electric_audio: AudioStreamPlayer3D = $SfxSwConductiveElectricPanelLoop

const STATE_CONFIGS: Dictionary = {
	ElementState.NEUTRAL: {
		"uv_offset":       Vector3(-0.008, 0.352, 0.0),
		"albedo_color":    Color.WHITE,
		"emission_color":  Color.WHITE,
		"emission_energy": 0.2,
	},
	ElementState.HEAT: {
		"uv_offset":       Vector3(0.245, 0.352, 0.0),
		"albedo_color":    Color(1.0, 0.0, 0.0, 1.0),
		"emission_color":  Color(1.0, 0.0, 0.0, 1.0),
		"emission_energy": 1.0,
	},
	ElementState.CHILL: {
		"uv_offset":       Vector3(0.741, 0.352, 0.0),
		"albedo_color":    Color(0.0, 0.8, 1.0, 1.0),
		"emission_color":  Color(0.0, 0.8, 1.0, 1.0),
		"emission_energy": 1.0,
	},
	ElementState.ELECTRIC: {
		"uv_offset":       Vector3(0.49, 0.352, 0.0),
		"albedo_color":    Color(0.0, 1.0, 0.082, 1.0),
		"emission_color":  Color(0.0, 1.0, 0.082, 1.0),
		"emission_energy": 1.0,
	},
}

var _uv_mat: StandardMaterial3D
var _emission_mat: StandardMaterial3D

func _ready() -> void:
	icon_mesh = get_node_or_null("ConductivesPanel/MeshInstance3D")
	
	panel_meshes = [
		get_node_or_null("ConductivesPanel/SM_ConductivePanel_A_mo"),
		get_node_or_null("ConductivesPanel/SM_ConductivePanel_B_mo"),
		get_node_or_null("ConductivesPanel/SM_ConductivePanel_C_mo")
	]
	
	panel_collisions = [
		get_node_or_null("FORM_A_Collision"),
		get_node_or_null("FORM_B_Collision"),
		get_node_or_null("FORM_C_Collision")
	]

	heat_particles = [
		get_node_or_null("FireParticles/Embers"),
		get_node_or_null("FireParticles/HeatDistortion"),
		get_node_or_null("FireParticles/Smoke")
	]
	
	chill_particles = [
		get_node_or_null("IceParticles/Snowflakes"),
		get_node_or_null("IceParticles/ColdSmoke")
	]
	
	electric_particles = [
		get_node_or_null("ElectricParticles/Snowflakes"),
		get_node_or_null("ElectricParticles/Snowflakes2")
	]
	
	_init_materials()
	_update_shape()
	apply_state()

func _update_shape() -> void:
	for i in range(panel_meshes.size()):
		if panel_meshes[i]:
			panel_meshes[i].visible = (i == panel_shape)
			
	for i in range(panel_collisions.size()):
		if panel_collisions[i]:
			var is_active = (i == panel_shape)
			panel_collisions[i].disabled = !is_active
			panel_collisions[i].process_mode = Node.PROCESS_MODE_INHERIT if is_active else Node.PROCESS_MODE_DISABLED

func _init_materials() -> void:
	if icon_mesh:
		var src := icon_mesh.get_active_material(0) as StandardMaterial3D
		_uv_mat = src.duplicate() if src else StandardMaterial3D.new()
		icon_mesh.set_surface_override_material(0, _uv_mat)

	if not _emission_mat:
		for mesh in panel_meshes:
			if mesh:
				var src := mesh.get_active_material(emission_surface_index) as StandardMaterial3D
				if src:
					_emission_mat = src.duplicate()
					_emission_mat.emission_enabled = true
					break
		
		if not _emission_mat:
			_emission_mat = StandardMaterial3D.new()
			_emission_mat.emission_enabled = true

	for mesh in panel_meshes:
		if mesh:
			mesh.set_surface_override_material(emission_surface_index, _emission_mat)

func _on_detection_area_area_entered(area: Area3D) -> void:
	if Engine.is_editor_hint():
		return
	
	if Manager.right_hand.current_state == Manager.right_hand.HandState.HOLDING: return
	if Manager.right_hand.current_state == Manager.right_hand.HandState.IDLE: return
	if area.name == "ConductiveArea":
		if Manager.right_hand.current_hand_node.name == "ConductiveHand":
			Manager.right_hand.current_hand_node.change_state(panel_type)
	apply_state()

func set_panel_type(new_type: ElementState) -> void:
	panel_type = new_type

func apply_state() -> void:
	var state: ElementState = panel_type
	var config: Dictionary = STATE_CONFIGS[state]
	if _uv_mat:
		_uv_mat.uv1_offset = config["uv_offset"]
	
	if _emission_mat:
		_emission_mat.albedo_color = config["albedo_color"]
		_emission_mat.emission = config["emission_color"]
		_emission_mat.emission_energy_multiplier = config["emission_energy"]
		
	_update_particles(state)
	if not Engine.is_editor_hint():
		_update_audio(state)

func _update_particles(state: ElementState) -> void:
	for p in heat_particles:
		if p: _toggle_p(p, state == ElementState.HEAT)
	for p in chill_particles:
		if p: _toggle_p(p, state == ElementState.CHILL)
	for p in electric_particles:
		if p: _toggle_p(p, state == ElementState.ELECTRIC)

func _toggle_p(p: GPUParticles3D, active: bool) -> void:
	if Engine.is_editor_hint():
		p.visible = active
	else:
		p.emitting = active
		p.visible = true

func _update_audio(state: ElementState) -> void:
	_stop_all_audio()
	match state:
		ElementState.NEUTRAL:  return
		ElementState.HEAT:     if heat_audio:     heat_audio.play()
		ElementState.CHILL:    if chill_audio:    chill_audio.play()
		ElementState.ELECTRIC: if electric_audio: electric_audio.play()

func _stop_all_audio() -> void:
	if heat_audio and heat_audio.playing: heat_audio.stop()
	if chill_audio and chill_audio.playing: chill_audio.stop()
	if electric_audio and electric_audio.playing: electric_audio.stop()

func _set_panel_visible(visibility: bool) -> void:
	for p in heat_particles:
		if p: p.visible = visibility and panel_type == ElementState.HEAT
	for p in chill_particles:
		if p: p.visible = visibility and panel_type == ElementState.CHILL
	for p in electric_particles:
		if p: p.visible = visibility and panel_type == ElementState.ELECTRIC

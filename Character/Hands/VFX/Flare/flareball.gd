extends RigidBody3D

@onready var gpu_particles_3d = $GPUParticles3D
@onready var omni_light_3d = $OmniLight3D
@onready var ball: MeshInstance3D = $MeshInstance3D
@onready var gpu_particles_3d_2: GPUParticles3D = $GPUParticles3D2
@onready var impact_player: AudioStreamPlayer3D = $ImpactPlayer

@export var impact: Array[AudioStream]

var frame: float = 0.0
var frame_1: float = 0.0

var flareballdecal = preload("res://Character/Hands/VFX/Flare/flaredecal.tscn")

var ball_material: ShaderMaterial = null

func _ready():
	ball_material = ball.get_surface_override_material(0)
	if ball_material == null: ball_material = ball.get_active_material(0)
	if ball_material:
		ball_material = ball_material.duplicate()
		ball.set_surface_override_material(0, ball_material)

func _process(delta):
	frame += 1.0 * delta
	if frame > 10: queue_free()
	if omni_light_3d != null:
		omni_light_3d.rotation.y += 0.1
		if omni_light_3d.light_energy > 0.0:
			omni_light_3d.light_energy -= 1.0 * delta
			if omni_light_3d.light_energy <= 0.0: omni_light_3d.queue_free()
	if frame > 6.0:
		gpu_particles_3d.emitting = false
		$GPUParticles3D2.emitting = false
		$GPUParticles3D3.emitting = false
		ball_material.set_shader_parameter("rim_intensity", lerpf(ball_material.get_shader_parameter("rim_intensity"), 0.0, 3.0 * delta))
		ball_material.set_shader_parameter("emission_strength", lerpf(ball_material.get_shader_parameter("emission_strength"), 0.0, 3.0 * delta))
	#frame_1 += 5.0 * delta
	#if frame_1 > 5.0:
		#frame_1 = 0.0
		#gpu_particles_3d.amount -= 1

func spawn_decal():
	var decal_chance := 0.4
	var from = global_position
	var to = from + Vector3.DOWN * 0.5
	
	var params = PhysicsRayQueryParameters3D.new()
	params.from = from
	params.to = to
	params.exclude = [self]
	params.collide_with_bodies = true
	params.collide_with_areas = true
	
	var result = get_world_3d().direct_space_state.intersect_ray(params)
	if randf() <= decal_chance:
		if result:
			var point = result["position"]
			#var normal = result["normal"]
			var decal = flareballdecal.instantiate()
			#var up_vector = Vector3.UP if abs(normal.dot(Vector3.UP)) < 0.99 else Vector3.FORWARD
			get_parent().add_child(decal)
			decal.global_position = point
			#decal.look_at(from - normal)
			
			#var mesh = decal.get_node("MeshInstance3D") as MeshInstance3D
			#var mat: ShaderMaterial = mesh.get_surface_override_material(0)
			#mat.set_shader_parameter("erosion", lerpf(mat.get_shader_parameter("erosion"), 1.1, 0.2 * delta))
			var timer = get_tree().create_timer(6.0)
			timer.timeout.connect(decal.queue_free)

func _on_body_entered(body: Node):
	#impact_sfx._on_hand_signal_connector_hand_used()
	if body.is_in_group("Player"):
		_play_one_shot(impact.pick_random(), impact_player)
		return
	var state = PhysicsServer3D.body_get_direct_state(get_rid())
	for i in range(state.get_contact_count()):
		var normal = state.get_contact_local_normal(i)
		if normal.dot(Vector3.UP) > 0.7: linear_damp = 13.0; spawn_decal(); return

func _on_body_exited(body: Node):
	if body.is_in_group("Player"): return
	linear_damp = 0.3

func _play_one_shot(stream: AudioStream, p: AudioStreamPlayer3D) -> void:
	if not stream: return
	p.stream = stream
	p.play()

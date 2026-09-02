extends RigidBody3D

@onready var gpu_particles_3d = $GPUParticles3D
@onready var omni_light_3d = $OmniLight3D
@onready var impact = $Impact
@onready var ball: MeshInstance3D = $MeshInstance3D
@onready var gpu_particles_3d_2: GPUParticles3D = $GPUParticles3D

var frame: float = 0.0
var frame_1: float = 0.0

var ball_material: StandardMaterial3D = null

func _ready():
	ball_material = ball.get_surface_override_material(0)
	if ball_material == null:
		ball_material = ball.get_active_material(0)
	if ball_material:
		ball_material = ball_material.duplicate()
		ball.set_surface_override_material(0, ball_material)

func _process(delta):
	frame += 1.0 * delta
	if frame > 10:
		queue_free()
	if omni_light_3d.light_energy > 0.0:
		omni_light_3d.light_energy -= 1.0 * delta
		if omni_light_3d.light_energy == 0.0:
			omni_light_3d.queue_free()
	if frame > 6.0:
		gpu_particles_3d.emitting = false
		ball_material.rim_enabled = false
	#frame_1 += 5.0 * delta
	#if frame_1 > 5.0:
		#frame_1 = 0.0
		#gpu_particles_3d.amount -= 1

func _on_area_3d_body_entered(body: Node3D) -> void:
	impact.play()
	if body.is_in_group("Player"):
		return
	freeze = true

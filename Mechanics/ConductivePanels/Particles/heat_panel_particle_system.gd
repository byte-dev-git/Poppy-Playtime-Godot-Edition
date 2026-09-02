@tool
class_name HeatParticleSystem
extends Node3D

## NS_CHPanel_HeatPowerIdle - Conductive Hand Heat Panel Idle Effect
## Converted from UE5 Niagara System (Poppy Playtime Chapter 5)
## 3 emitters: Embers, Heat Distortion, Smoke/Fire

# === System Parameters (UE: ExposedParameters) ===
@export_group("System")
@export_range(0.0, 2.0) var system_intensity: float = 1.0:
	set(val):
		system_intensity = val
		_update_all()
@export_range(0.0, 2.0) var stunned_intensity: float = 0.0:
	set(val):
		stunned_intensity = val
		_update_all()

# === Ember Parameters ===
@export_group("Embers")
@export var ember_spawn_rate: float = 65.0
@export var ember_lifetime_min: float = 0.5
@export var ember_lifetime_max: float = 4.0
@export var ember_velocity_min: float = 10.0 ## UE units (cm)
@export var ember_velocity_max: float = 50.0
@export var ember_cone_angle_max: float = 30.0 ## degrees
@export var ember_origin_sphere_radius: float = 20.0 ## UE units
@export var ember_sprite_size_min: float = 1.0
@export var ember_sprite_size_max: float = 2.0
@export var ember_color_intensity_scale: float = 1.0

# === Heat Distortion Parameters ===
@export_group("Heat Distortion")
@export var hd_spawn_rate: float = 2.0
@export var hd_lifetime_min: float = 1.0
@export var hd_lifetime_max: float = 1.75
@export var hd_origin_ring_radius: float = 100.0
@export var hd_sprite_size: float = 50.0

# === Smoke Parameters ===
@export_group("Smoke")
@export var smoke_spawn_rate: float = 50.0
@export var smoke_lifetime_min: float = 1.0
@export var smoke_lifetime_max: float = 2.0
@export var smoke_sprite_size_min: float = 25.0
@export var smoke_sprite_size_max: float = 30.0
@export var smoke_alpha_min: float = 0.2
@export var smoke_alpha_max: float = 0.4
@export var smoke_color_intensity: float = 300.0
@export var smoke_velocity_min: Vector3 = Vector3(0, 5, 0)
@export var smoke_velocity_max: Vector3 = Vector3(0, 10, 0)

# === Node References ===
var _embers: GPUParticles3D
var _heat_distortion: GPUParticles3D
var _smoke: GPUParticles3D


func _ready() -> void:
	_embers = $Embers if has_node("Embers") else null
	_heat_distortion = $HeatDistortion if has_node("HeatDistortion") else null
	_smoke = $Smoke if has_node("Smoke") else null
	_update_all()


func _update_all() -> void:
	var intensity = system_intensity * (1.0 - stunned_intensity * 0.5)
	_update_embers(intensity)
	_update_heat_distortion(intensity)
	_update_smoke(intensity)


func _update_embers(intensity: float) -> void:
	if not _embers or not _embers.process_material:
		return
	var mat := _embers.process_material as ShaderMaterial
	if not mat:
		return
	
	mat.set_shader_parameter("spawn_rate", ember_spawn_rate * intensity)
	mat.set_shader_parameter("lifetime_min", ember_lifetime_min)
	mat.set_shader_parameter("lifetime_max", ember_lifetime_max)
	mat.set_shader_parameter("velocity_min", ember_velocity_min)
	mat.set_shader_parameter("velocity_max", ember_velocity_max)
	mat.set_shader_parameter("cone_angle_max", ember_cone_angle_max)
	mat.set_shader_parameter("origin_sphere_radius", ember_origin_sphere_radius)
	mat.set_shader_parameter("sprite_size_min", ember_sprite_size_min)
	mat.set_shader_parameter("sprite_size_max", ember_sprite_size_max)
	mat.set_shader_parameter("color_intensity_scale", ember_color_intensity_scale * intensity)
	
	_embers.amount = int(ember_spawn_rate * intensity)
	_embers.lifetime = (ember_lifetime_min + ember_lifetime_max) / 2.0


func _update_heat_distortion(intensity: float) -> void:
	if not _heat_distortion or not _heat_distortion.process_material:
		return
	var mat := _heat_distortion.process_material as ShaderMaterial
	if not mat:
		return
	
	mat.set_shader_parameter("spawn_rate", hd_spawn_rate * intensity)
	mat.set_shader_parameter("lifetime_min", hd_lifetime_min)
	mat.set_shader_parameter("lifetime_max", hd_lifetime_max)
	mat.set_shader_parameter("origin_ring_radius", hd_origin_ring_radius)
	mat.set_shader_parameter("sprite_size", hd_sprite_size)
	
	_heat_distortion.amount = max(1, int(hd_spawn_rate * intensity))
	_heat_distortion.lifetime = (hd_lifetime_min + hd_lifetime_max) / 2.0


func _update_smoke(intensity: float) -> void:
	if not _smoke or not _smoke.process_material:
		return
	var mat := _smoke.process_material as ShaderMaterial
	if not mat:
		return
	
	mat.set_shader_parameter("spawn_rate", smoke_spawn_rate * intensity)
	mat.set_shader_parameter("lifetime_min", smoke_lifetime_min)
	mat.set_shader_parameter("lifetime_max", smoke_lifetime_max)
	mat.set_shader_parameter("sprite_size_min", smoke_sprite_size_min)
	mat.set_shader_parameter("sprite_size_max", smoke_sprite_size_max)
	mat.set_shader_parameter("alpha_min", smoke_alpha_min * intensity)
	mat.set_shader_parameter("alpha_max", smoke_alpha_max * intensity)
	mat.set_shader_parameter("color_intensity", smoke_color_intensity * intensity)
	mat.set_shader_parameter("velocity_min", smoke_velocity_min)
	mat.set_shader_parameter("velocity_max", smoke_velocity_max)
	
	_smoke.amount = int(smoke_spawn_rate * intensity)
	_smoke.lifetime = (smoke_lifetime_min + smoke_lifetime_max) / 2.0


## Activate/deactivate the entire system
func set_active(active: bool) -> void:
	if _embers: _embers.emitting = active
	if _heat_distortion: _heat_distortion.emitting = active
	if _smoke: _smoke.emitting = active


## Smooth transition to stunned state
func set_stunned(stunned: bool, duration: float = 0.5) -> void:
	var tween = create_tween()
	tween.tween_property(self, "stunned_intensity", 1.0 if stunned else 0.0, duration)


## Smooth transition of overall intensity
func set_system_intensity(target: float, duration: float = 0.3) -> void:
	var tween = create_tween()
	tween.tween_property(self, "system_intensity", target, duration)

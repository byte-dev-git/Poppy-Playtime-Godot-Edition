extends Node3D

@onready var spawn = $Spawn
@onready var flare_counter = $SK_FlareHand/SK_FlareHand_ao/Skeleton3D/Mesh/FlareCounter
@onready var flare_counter_2 = $SK_FlareHand/SK_FlareHand_ao/Skeleton3D/Mesh/FlareCounter2
@onready var shoot_sfx_player: AudioStreamPlayer3D = $ShootSFX_Player
@onready var fail_sfx_player: AudioStreamPlayer3D = $FailSFX_Player

@export var shoot_sfx: Array[AudioStream]
@export var fail_sfx: Array[AudioStream]

var shoot_cooldown: float = 0.5

var flares_count: int = 5
var max_flares: int = 5
var can_shoot: bool = true

const FLARE = preload("res://Character/Hands/VFX/Flare/flareball.tscn")

func _handle_fail():
	if not can_shoot:
		return
		
	_start_cooldown()
	_play_sound(fail_sfx_player, fail_sfx)

func _shoot():
	if not can_shoot:
		return

	if flares_count < 1:
		_handle_fail()
		return
	
	_start_cooldown()
	_play_sound(shoot_sfx_player, shoot_sfx)
	
	Manager.player.anim_tree.set("parameters/ShootFlare/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	var flare_node = FLARE.instantiate()
	var speed = 30.0
	get_tree().root.add_child(flare_node) 
	
	flare_node.global_position = spawn.global_position
	var camera_basis = Manager.player.camera.global_transform.basis
	flare_node.linear_velocity = -camera_basis.z * speed
	flares_count -= 1
	flare_counter.visible = true
	flare_counter.play("Recharge")
	flare_counter_2.frame = flares_count

func _start_cooldown():
	can_shoot = false
	get_tree().create_timer(shoot_cooldown).timeout.connect(func(): can_shoot = true)

func _on_flare_counter_animation_finished():
	flares_count = clampi(flares_count + 1, 0, max_flares)
	flare_counter_2.frame = flares_count
	
	if flares_count < max_flares:
		flare_counter.visible = true
		flare_counter.play("Recharge")
	else:
		flare_counter.visible = false

func _play_sound(p: AudioStreamPlayer3D, sound_pack: Array[AudioStream]):
	if !p is AudioStreamPlayer3D or p == null: return
	if sound_pack.size() >= 1: p.stream = sound_pack.pick_random()
	p.play()

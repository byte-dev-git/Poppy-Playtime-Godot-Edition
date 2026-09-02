extends Node3D

@onready var pickup: AudioStreamPlayer3D = $SwObjectPickup
@onready var sm_glowby: Node3D = $SM_Glowby


func _on_interaction_player_interacted() -> void:
	pick_glowby()

func _on_grab_target_on_released(_hand_side: String) -> void:
	pick_glowby()

func pick_glowby():
	pickup.play()
	sm_glowby.queue_free()
	Manager.player.lower_grabpack()
	await get_tree().create_timer(0.7).timeout
	Manager.player.raise_grabpack()
	Manager.player.have_glowby = true
	await get_tree().create_timer(0.05).timeout
	self.queue_free()

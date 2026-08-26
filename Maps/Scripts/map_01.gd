extends Node3D



@onready var power_platform_anim: AnimationPlayer = $Machanics/RizingPlatform/PowerPlatformAnim
@onready var bp_player: CharacterBody3D = $BP_Player


func _process(_delta: float) -> void:
	if bp_player.global_position.y <= -8.0:
		bp_player.global_position = Vector3(1.723, 0.0, 6.434)

func _on_power_pole_pole_powered() -> void:
	if not power_platform_anim == null and not $Machanics/RizingPlatform/power_receiver.poles_powered:
		power_platform_anim.play("Rizing")
	else: 
		return

func _on_power_pole_pole_dispowered() -> void:
	if not power_platform_anim == null and not $Machanics/RizingPlatform/power_receiver.poles_powered:
		power_platform_anim.play_backwards("Rizing")
	else: 
		return

func _on_power_receiver_powered() -> void:
	power_platform_anim.play("Rized")
	power_platform_anim.queue_free()
	$Machanics/HandScanner.is_off = false

func _on_hand_scanner_scan_complete() -> void:
	$Machanics/SlidingDoors.open_door()

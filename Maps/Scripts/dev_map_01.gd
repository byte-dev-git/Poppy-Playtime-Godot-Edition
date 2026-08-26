extends Node3D



@onready var bp_player: CharacterBody3D = $BP_Player
@onready var battery_socket_2: StaticBody3D = $Mechanics/BatterySocket2

func _process(_delta: float) -> void:
	if bp_player.global_position.y <= -8.0:
		bp_player.global_position = Vector3.ZERO

func _on_hand_scanner_2_scan_complete() -> void:
	battery_socket_2.enabled  = true

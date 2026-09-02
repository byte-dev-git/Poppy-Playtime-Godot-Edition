extends Node3D


@onready var battery_socket_3: StaticBody3D = $Mechanics/BatterySocket3


func _on_cable_cable_powered() -> void:
	battery_socket_3.enabled = true

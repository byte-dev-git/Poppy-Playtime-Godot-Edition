extends Area3D
##Detects when a flare enters the area.
class_name FlareDetector

signal flare_entered
@export var usable_once: bool = true
@export var flare_time: float = 0.0

var used: bool = false

func _ready() -> void:
	connect("area_entered", Callable(area_detected))

func area_detected(area):
	if area.is_in_group("FlareBall") and not used:
		if flare_time > 0.0:
			if area.get_parent().frame > flare_time: return
		flare_entered.emit()
		if usable_once:
			used = true

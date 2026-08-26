@tool
extends Node3D


@onready var standing: MeshInstance3D = $StandingRef
@onready var crouching: MeshInstance3D = $CrouchingRef

@export var type: bool = true:
	set(value):
		type = value
		update_preview(value)

func _ready() -> void:
	if not Engine.is_editor_hint():
		self.queue_free()

func update_preview(v: bool):
	if Engine.is_editor_hint():
		standing.visible = v
		crouching.visible = !v

extends PickableObject


@onready var limon_drop: AudioStreamPlayer3D = $SwSfxLimonDrop
@onready var limon_pickup: AudioStreamPlayer3D = $SwSfxLimonPickup


var limon_held: bool = false
var last_limon_held_state: bool = false

func limon_sound(i: bool):
	if i == true:
		limon_pickup.play()
	else: 
		limon_drop.play()

func _process(_delta: float) -> void:
	limon_held = is_held
	if limon_held != last_limon_held_state:
		limon_sound(limon_held)
		last_limon_held_state = limon_held

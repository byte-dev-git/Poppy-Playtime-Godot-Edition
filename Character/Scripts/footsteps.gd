extends Node
class_name Footsteps

enum SoundVariant {
	Concrete,
	Glass,
	Metal,
	Metal_Grate,
	Carpet,
	Vent,
	Plastic,
	Wood
}

@export var type: SoundVariant

extends Node3D



@export var particles: Array[GPUParticles3D]

@onready var grab_target: GrabTarget = $GrabTarget

var powered = false

func _ready() -> void:
	grab_target.on_grabbed.connect(_on_grab_target_on_grabbed)

func _on_grab_target_on_grabbed(hand_side: String) -> void:
	if not powered:
		if Manager.right_hand.current_hand_node.name == "ConductiveHand":
			powered = (Manager.right_hand.current_hand_node.current_state == Manager.right_hand.current_hand_node.ElementState.ELECTRIC)
			if Manager.right_hand.current_hand_node.current_state == Manager.right_hand.current_hand_node.ElementState.ELECTRIC: Manager.right_hand.current_hand_node.change_state(Manager.right_hand.current_hand_node.ElementState.NEUTRAL)
		else: powered = false
	
	for p in particles:
		p.emitting = powered
		break

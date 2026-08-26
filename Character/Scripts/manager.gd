extends Node

var player: CharacterBody3D = null
var cable_manager: Node = null
var left_hand: Node3D = null
var right_hand: Node3D = null

func start() -> void:
	player = get_tree().get_first_node_in_group("Player")
	cable_manager = get_tree().get_first_node_in_group("CableManager")
	left_hand = get_tree().get_first_node_in_group("LeftHand")
	right_hand = get_tree().get_first_node_in_group("RightHand")

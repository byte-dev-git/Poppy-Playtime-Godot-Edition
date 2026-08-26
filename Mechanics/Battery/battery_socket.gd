@tool
extends StaticBody3D

signal powered
signal dispowered

@onready var battery_pos: Node3D = $BatteryPos
@onready var grab_target: GrabTarget = $GrabTarget
@onready var power_down: AudioStreamPlayer3D = $SwBatteryPowerDown01
@onready var power_on: AudioStreamPlayer3D = $SwBatteryPowerOn01
@onready var idle_hum_loop: AudioStreamPlayer3D = $SwBatteryIdleHumLoop01
@onready var sm_battery: Node3D = $SM_Battery
@onready var sm_battery_col: CollisionShape3D = $SM_Battery_Col
@onready var mesh: MeshInstance3D = $SM_BatteryFrame/Mesh

@export var start_with_battery: bool = true:
	set(value):
		start_with_battery = value
		_update_preview()

@export var removable: bool = true:
	set(value):
		removable = value
		_update_preview()

@export var enabled: bool = true:
	set(value):
		enabled = value
		_update_preview()

var installed_battery: PickableObject = null
var battery_in: bool = false

const BATTERY = preload("res://Mechanics/Battery/battery.tscn")
const M_BATTERY_SOCKET_ACTIVE = preload("uid://dwnhyvxmfpanh")
const M_BATTERY_SOCKET_INACTIVE = preload("uid://cmiv2j53j6wv1")

func _ready() -> void:
	_update_preview()

	# Stop game execution here if running inside the Godot Editor
	if Engine.is_editor_hint():
		return

	if grab_target:
		grab_target.add_to_group("BatteryHolder")
		if not grab_target.on_grabbed.is_connected(_on_grab_target_on_grabbed):
			grab_target.on_grabbed.connect(_on_grab_target_on_grabbed)

	if start_with_battery and enabled:
		if not removable:
			if sm_battery:
				sm_battery.visible = true
			if sm_battery_col:
				sm_battery_col.disabled = false
			battery_in = true
			_set_socket_target_enabled(false)
			if idle_hum_loop and not idle_hum_loop.playing:
				idle_hum_loop.play()
			powered.emit()
		else:
			if not is_instance_valid(installed_battery):
				installed_battery = BATTERY.instantiate() as PickableObject
			_dock_battery(installed_battery)
	else:
		_set_socket_target_enabled(not battery_in and enabled)

func _update_preview() -> void:
	if not is_node_ready():
		return

	# Enable/disable grab targets based on state
	_set_socket_target_enabled(not battery_in and enabled)

	# Preview static battery mesh visibility
	var should_show_battery = start_with_battery if Engine.is_editor_hint() else (battery_in and not removable)
	if sm_battery:
		sm_battery.visible = should_show_battery
	if sm_battery_col:
		sm_battery_col.disabled = not should_show_battery

	# Preview socket active/inactive material
	var mesh_to_update = mesh if mesh else (sm_battery as MeshInstance3D)
	if mesh_to_update:
		if !enabled:
			mesh_to_update.set_surface_override_material(0, M_BATTERY_SOCKET_INACTIVE)
		else:
			mesh_to_update.set_surface_override_material(0, M_BATTERY_SOCKET_ACTIVE)

func _on_grab_target_on_grabbed(hand_side: String) -> void:
	if !enabled or battery_in or is_instance_valid(installed_battery):
		return
	
	var hand = _get_hand(hand_side)
	if not hand:
		return
	
	if hand.is_held and is_instance_valid(hand.held_object):
		var held_item = hand.held_object
		if held_item.is_in_group("Battery"):
			hand.pickup_target(false)
			_dock_battery(held_item)
			if hand.has_method("start_retract"):
				hand.start_retract()

func _dock_battery(battery: PickableObject) -> void:
	if !enabled:
		return

	battery_in = true

	if power_on:
		power_on.play()
	if idle_hum_loop and not idle_hum_loop.playing:
		idle_hum_loop.play()

	_set_socket_target_enabled(false)

	if not removable:
		if is_instance_valid(battery):
			battery.queue_free()
		installed_battery = null
	else:
		installed_battery = battery

		if battery.get_parent():
			battery.reparent(battery_pos)
		else:
			battery_pos.add_child(battery)

		battery.transform = Transform3D.IDENTITY
		battery.freeze = true

		var batt_target = _get_battery_grab_target(installed_battery)
		if batt_target:
			batt_target.is_disabled = false

		if not installed_battery.picked_up.is_connected(_on_battery_picked_up):
			installed_battery.picked_up.connect(_on_battery_picked_up)

	_update_preview()
	powered.emit()

func _on_battery_picked_up(_hand_side: String) -> void:
	if is_instance_valid(installed_battery):
		if installed_battery.picked_up.is_connected(_on_battery_picked_up):
			installed_battery.picked_up.disconnect(_on_battery_picked_up)

		installed_battery.transform = Transform3D.IDENTITY
		installed_battery = null

	battery_in = false

	if idle_hum_loop and idle_hum_loop.playing:
		idle_hum_loop.stop()
	if power_down:
		power_down.play()

	_update_preview()
	dispowered.emit()

func _set_socket_target_enabled(enabled: bool) -> void:
	if grab_target:
		grab_target.is_disabled = not enabled or !enabled

func _get_battery_grab_target(battery: PickableObject) -> GrabTarget:
	if battery.grab_target:
		return battery.grab_target
	var targets = battery.find_children("*", "GrabTarget")
	return targets[0] as GrabTarget if targets.size() > 0 else null

func _get_hand(hand_side: String) -> Node3D:
	return Manager.left_hand if hand_side.to_lower() == "left" else Manager.right_hand

extends StaticBody3D

signal pole_powered
signal pole_dispowered

@onready var sm_puzzle_pole_basic_mo: MeshInstance3D = $PowerSource/SM_PuzzlePole_Basic_mo
@onready var detection: Area3D = $Detection
@onready var pole_charged: AudioStreamPlayer3D = $SwConduitElectricPoleCharged
@onready var pole_discharged: AudioStreamPlayer3D = $SwConduitElectricPoleDischarged

const POWERED_MATERIAL: Material = preload("res://Mechanics/PowerPuzzle/M_PowerPole_Active.tres")
const UNPOWERED_MATERIAL: Material = preload("res://Mechanics/PowerPuzzle/M_PowerPole_Inactive.tres")

var required_cables_to_power: int = 1 

var is_powered: bool = false
var cable_manager: CableManager
var _surface_material: Material
var is_currently_powered: bool = false

func _ready() -> void:
	var cm_node = get_tree().get_first_node_in_group("CableManager")
	if cm_node is CableManager:
		cable_manager = cm_node
		
	# 1. Complete validation step before grabbing materials
	if sm_puzzle_pole_basic_mo and sm_puzzle_pole_basic_mo.mesh:
		if sm_puzzle_pole_basic_mo.mesh.get_surface_count() > 0:
			var mat = sm_puzzle_pole_basic_mo.get_active_material(0)
			if mat != null:
				_surface_material = mat.duplicate()
				sm_puzzle_pole_basic_mo.set_surface_override_material(0, _surface_material)
			else:
				push_error("PowerPole Error: No material assigned to Mesh surface 0!")
		else:
			push_error("PowerPole Error: Mesh asset loaded with 0 geometry surfaces!")
	else:
		push_error("PowerPole Error: MeshInstance3D node missing or Mesh property is completely empty!")

func set_power(state: bool) -> void:
	# 2. Always assign state parameters immediately to prevent logic feedback loops
	is_currently_powered = state
	is_powered = state
	
	# Safety check: if material setup failed in _ready, skip material logic but allow gameplay signals
	if _surface_material == null:
		if state: pole_powered.emit()
		else: pole_dispowered.emit()
		return

	if state:
		_surface_material.next_pass = POWERED_MATERIAL
		pole_powered.emit()
		if pole_charged and not pole_charged.playing: 
			pole_charged.play()
	else:
		_surface_material.next_pass = UNPOWERED_MATERIAL
		pole_dispowered.emit()
		if pole_discharged and not pole_discharged.playing: 
			pole_discharged.play()

func _process(_delta: float) -> void:
	# 3. Aggressive early exit if the core data structure is broken
	if cable_manager == null or _surface_material == null:
		return
		
	var wrapped_cables_count: int = 0
	
	for cable in cable_manager.cables:
		if cable != null and cable.is_active and cable.is_powered:
			if _is_cable_inside_area(cable):
				wrapped_cables_count += 1
				
	var conditions_met: bool = (wrapped_cables_count >= required_cables_to_power)
	
	if conditions_met != is_currently_powered:
		set_power(conditions_met)

func _is_cable_inside_area(cable: CablePhysics) -> bool:
	if cable.rope_points.size() < 2 or detection == null:
		return false

	for child in detection.get_children():
		if child is CollisionShape3D and child.shape != null and not child.disabled:
			if _cable_intersects_shape(cable, child):
				return true

	return false

func _cable_intersects_shape(cable: CablePhysics, col_shape: CollisionShape3D) -> bool:
	var inv_tf: Transform3D = col_shape.global_transform.affine_inverse()
	var shape: Shape3D = col_shape.shape

	for i in range(cable.rope_points.size() - 1):
		# Transform world positions into local shape space
		var p1: Vector3 = inv_tf * cable.rope_points[i]
		var p2: Vector3 = inv_tf * cable.rope_points[i + 1]

		if shape is SphereShape3D:
			var r: float = (shape as SphereShape3D).radius
			var closest := Geometry3D.get_closest_point_to_segment(Vector3.ZERO, p1, p2)
			if closest.length_squared() <= r * r:
				return true

		elif shape is BoxShape3D:
			var half_size: Vector3 = (shape as BoxShape3D).size * 0.5
			var aabb := AABB(-half_size, (shape as BoxShape3D).size)
			if aabb.has_point(p1) or aabb.has_point(p2) or aabb.intersects_segment(p1, p2) != null:
				return true

		elif shape is CylinderShape3D:
			var cyl := shape as CylinderShape3D
			var r: float = cyl.radius
			var half_h: float = cyl.height * 0.5

			if _is_point_in_cylinder(p1, r, half_h) or _is_point_in_cylinder(p2, r, half_h):
				return true

			var p1_2d := Vector2(p1.x, p1.z)
			var p2_2d := Vector2(p2.x, p2.z)
			
			# FIX: Swapped Geometry3D to Geometry2D and dropped '_2d' from function name
			var closest_2d := Geometry2D.get_closest_point_to_segment(Vector2.ZERO, p1_2d, p2_2d)

			if closest_2d.length_squared() <= r * r:
				var seg_vec_2d := p2_2d - p1_2d
				var t: float = 0.0
				if seg_vec_2d.length_squared() > 0.0001:
					t = (closest_2d - p1_2d).dot(seg_vec_2d) / seg_vec_2d.length_squared()
				t = clampf(t, 0.0, 1.0)
				if absf(lerpf(p1.y, p2.y, t)) <= half_h:
					return true

		elif shape is CapsuleShape3D:
			var cap := shape as CapsuleShape3D
			var half_h: float = maxf(0.0, (cap.height - cap.radius * 2.0) * 0.5)
			var cap_p1 := Vector3(0, -half_h, 0)
			var cap_p2 := Vector3(0, half_h, 0)
			var pts := Geometry3D.get_closest_points_between_segments(cap_p1, cap_p2, p1, p2)
			if pts[0].distance_squared_to(pts[1]) <= cap.radius * cap.radius:
				return true

	return false

func _is_point_in_cylinder(p: Vector3, radius: float, half_height: float) -> bool:
	return absf(p.y) <= half_height and (p.x * p.x + p.z * p.z) <= radius * radius

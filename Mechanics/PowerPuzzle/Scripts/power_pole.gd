@tool
extends StaticBody3D

signal pole_powered
signal pole_dispowered

@onready var sm_puzzle_pole_basic_mo: MeshInstance3D = $PowerSource/SM_PuzzlePole_Basic_mo
@onready var detection: Area3D = $Detection
@onready var pole_charged: AudioStreamPlayer3D = $SwConduitElectricPoleCharged
@onready var pole_discharged: AudioStreamPlayer3D = $SwConduitElectricPoleDischarged
@onready var light: OmniLight3D = $OmniLight3D

const POWERED_MATERIAL: Material = preload("res://Mechanics/PowerPuzzle/M_PowerPole_Active.tres")

var required_cables_to_power: int = 1 
var is_powered: bool = false
var cable_manager: Node
var _surface_material: Material
var is_currently_powered: bool = false
var active_power_color: Color = Color.WHITE


func _ready() -> void:
	if light == null and has_node("OmniLight3D"):
		light = $OmniLight3D
		
	if not Engine.is_editor_hint():
		var cm_node = get_tree().get_first_node_in_group("CableManager")
		if cm_node:
			cable_manager = cm_node
			
	_ensure_surface_material()
	set_expected_color(active_power_color)
	
	if sm_puzzle_pole_basic_mo and sm_puzzle_pole_basic_mo.mesh:
		if sm_puzzle_pole_basic_mo.mesh.get_surface_count() > 0:
			var mat = sm_puzzle_pole_basic_mo.get_active_material(0)
			if mat != null:
				_surface_material = mat.duplicate()
				sm_puzzle_pole_basic_mo.set_surface_override_material(0, _surface_material)

func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or cable_manager == null or _surface_material == null:
		return
		
	var wrapped_cables_count: int = 0
	
	for cable in cable_manager.cables:
		if cable != null and cable.is_active and cable.is_powered:
			if _is_cable_inside_area(cable):
				if "current_power_color" in cable and cable.current_power_color == active_power_color:
					wrapped_cables_count += 1
				
	var conditions_met: bool = (wrapped_cables_count >= required_cables_to_power)
	
	if conditions_met != is_currently_powered:
		set_power(conditions_met)

func set_expected_color(color: Color) -> void:
	active_power_color = color
	
	if light == null and has_node("OmniLight3D"):
		light = $OmniLight3D
	if light:
		light.light_color = active_power_color

	_ensure_surface_material()

	if _surface_material is StandardMaterial3D or _surface_material is ORMMaterial3D:
		_surface_material.emission_enabled = true
		_surface_material.emission = active_power_color

	if is_currently_powered:
		_apply_powered_next_pass()

func set_power(state: bool) -> void:
	is_currently_powered = state
	is_powered = state
	
	_ensure_surface_material()

	if _surface_material == null:
		if state: pole_powered.emit()
		else: pole_dispowered.emit()
		return

	if state:
		_apply_powered_next_pass()
		pole_powered.emit()
		
		if light: light.visible = true
		if pole_charged and not pole_charged.playing and not Engine.is_editor_hint(): 
			pole_charged.play()
	else:
		_surface_material.next_pass = null
		if light: light.visible = false
		pole_dispowered.emit()
		if pole_discharged and not pole_discharged.playing and not Engine.is_editor_hint(): 
			pole_discharged.play()

func _apply_powered_next_pass() -> void:
	if _surface_material == null:
		return
	var dynamic_mat = POWERED_MATERIAL.duplicate()
	if dynamic_mat is StandardMaterial3D or dynamic_mat is ORMMaterial3D:
		dynamic_mat.albedo_color = active_power_color
		dynamic_mat.emission_enabled = true
		dynamic_mat.emission = active_power_color
	_surface_material.next_pass = dynamic_mat

func _ensure_surface_material() -> void:
	if sm_puzzle_pole_basic_mo == null:
		return
	if _surface_material == null:
		var mat = sm_puzzle_pole_basic_mo.get_surface_override_material(0)
		if mat == null and sm_puzzle_pole_basic_mo.mesh and sm_puzzle_pole_basic_mo.mesh.get_surface_count() > 0:
			mat = sm_puzzle_pole_basic_mo.get_active_material(0)
		if mat != null:
			_surface_material = mat.duplicate()
			sm_puzzle_pole_basic_mo.set_surface_override_material(0, _surface_material)

func _is_cable_inside_area(cable: Node3D) -> bool:
	if cable.rope_points.size() < 2 or detection == null:
		return false

	for child in detection.get_children():
		if child is CollisionShape3D and child.shape != null and not child.disabled:
			if _cable_intersects_shape(cable, child):
				return true
	return false

func _cable_intersects_shape(cable: Node3D, col_shape: CollisionShape3D) -> bool:
	var inv_tf: Transform3D = col_shape.global_transform.affine_inverse()
	var shape: Shape3D = col_shape.shape

	for i in range(cable.rope_points.size() - 1):
		var p1: Vector3 = inv_tf * cable.rope_points[i]
		var p2: Vector3 = inv_tf * cable.rope_points[i + 1]

		if shape is SphereShape3D:
			var r: float = (shape as SphereShape3D).radius
			var closest := Geometry3D.get_closest_point_to_segment(Vector3.ZERO, p1, p2)
			if closest.length_squared() <= r * r: return true

		elif shape is BoxShape3D:
			var half_size: Vector3 = (shape as BoxShape3D).size * 0.5
			var aabb := AABB(-half_size, (shape as BoxShape3D).size)
			if aabb.has_point(p1) or aabb.has_point(p2) or aabb.intersects_segment(p1, p2) != null: return true

		elif shape is CylinderShape3D:
			var cyl := shape as CylinderShape3D
			var r: float = cyl.radius
			var half_h: float = cyl.height * 0.5

			if _is_point_in_cylinder(p1, r, half_h) or _is_point_in_cylinder(p2, r, half_h): return true

			var p1_2d := Vector2(p1.x, p1.z)
			var p2_2d := Vector2(p2.x, p2.z)
			
			var closest_2d := Geometry2D.get_closest_point_to_segment(Vector2.ZERO, p1_2d, p2_2d)

			if closest_2d.length_squared() <= r * r:
				var seg_vec_2d := p2_2d - p1_2d
				var t: float = 0.0
				if seg_vec_2d.length_squared() > 0.0001:
					t = (closest_2d - p1_2d).dot(seg_vec_2d) / seg_vec_2d.length_squared()
				t = clampf(t, 0.0, 1.0)
				if absf(lerpf(p1.y, p2.y, t)) <= half_h: return true

		elif shape is CapsuleShape3D:
			var cap := shape as CapsuleShape3D
			var half_h: float = maxf(0.0, (cap.height - cap.radius * 2.0) * 0.5)
			var cap_p1 := Vector3(0, -half_h, 0)
			var cap_p2 := Vector3(0, half_h, 0)
			var pts := Geometry3D.get_closest_points_between_segments(cap_p1, cap_p2, p1, p2)
			if pts[0].distance_squared_to(pts[1]) <= cap.radius * cap.radius: return true

	return false

func _is_point_in_cylinder(p: Vector3, radius: float, half_height: float) -> bool:
	return absf(p.y) <= half_height and (p.x * p.x + p.z * p.z) <= radius * radius

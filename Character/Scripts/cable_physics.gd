extends Node3D
class_name CablePhysics

@export_category("References")
@export var launch_hand: Node3D       
@export var player: CharacterBody3D   
@export var start_transform: Node3D
@export var end_transform: Node3D
@export var lookat_marker: Marker3D
@export var cable_manager: CableManager

@export_category("Settings")
@export var collision_layer: int = 1
@export var cable_radius: float = 0.05
@export var radial_segments: int = 8
@export var surface_offset: float = 0.015
@export var visual_segments_per_section: int = 8
@export var sag_amount: float = 0.15

@export_category("Materials")
@export var glowing_material: StandardMaterial3D
@export var normal_material: StandardMaterial3D

var is_powered: bool = false
var rope_points: Array[Vector3] = []
var rope_normals: Array[Vector3] = [] 
var is_active: bool = false
var mesh_instance: MeshInstance3D
var current_swing_length: float = 0.0

func _ready() -> void:
	mesh_instance = MeshInstance3D.new()
	add_child(mesh_instance)
	if normal_material != null:
		mesh_instance.material_override = normal_material
	initialize_cable()

func start_swing_capture() -> void:
	current_swing_length = get_cable_length()

func apply_swing_mechanics(delta: float) -> void:
	if not player or launch_hand.current_state != launch_hand.HandState.ATTACHED:
		if current_swing_length > 0.0:
			if player and "swinging" in player:
				player.swinging = false
			current_swing_length = 0.0
		return

	var target = launch_hand.current_target_node
	if target and "is_swingable" in target and target.is_swingable:
		if current_swing_length <= 0.0:
			start_swing_capture()

		var anchor = rope_points[1] if rope_points.size() > 1 else launch_hand.global_position
		var wrapped_length = get_cable_length() - player.global_position.distance_to(anchor)
		var allowed_radius = max(0.1, current_swing_length - wrapped_length)
		
		if player.has_method("apply_swing"):
			player.apply_swing(anchor, allowed_radius, delta)

func initialize_cable() -> void:
	rope_points.clear()
	rope_normals.clear()
	if start_transform and end_transform:
		rope_points.append(start_transform.global_position)
		rope_normals.append(Vector3.UP)
		rope_points.append(end_transform.global_position)
		rope_normals.append(Vector3.UP)

func set_powered(powered: bool) -> void:
	is_powered = powered
	if mesh_instance != null:
		mesh_instance.material_override = glowing_material if is_powered else normal_material

func _physics_process(_delta: float) -> void:
	if not is_active:
		mesh_instance.mesh = null
		if rope_points.size() > 0:
			rope_points.clear()
			rope_normals.clear()
		return
		
	if rope_points.size() < 2:
		initialize_cable()
		return
		
	rope_points[0] = start_transform.global_position
	rope_points[rope_points.size() - 1] = end_transform.global_position
	
	if launch_hand and launch_hand.current_state == launch_hand.HandState.RETRACTING:
		pass
	else:
		handle_wrapping()
		handle_unwrapping()

func _process(_delta: float) -> void:
	if not is_active or rope_points.size() < 2:
		return
		
	rope_points[0] = start_transform.global_position
	rope_points[rope_points.size() - 1] = end_transform.global_position
	
	if lookat_marker != null and rope_points.size() >= 2:
		lookat_marker.global_position = rope_points[1]

	render_rope()

func handle_wrapping() -> void:
	var space_state = get_world_3d().direct_space_state
	var i = 0
	while i < rope_points.size() - 1:
		var from = rope_points[i]
		var to = rope_points[i + 1]
		var dir = to - from
		var dist = dir.length()
		
		if dist <= 0.1:
			i += 1
			continue
			
		var dir_norm = dir / dist
		var ray_start = from + dir_norm * 0.05
		var ray_end = to - dir_norm * 0.05
		
		if ray_start.distance_to(ray_end) <= 0.05:
			i += 1
			continue
			
		var query = PhysicsRayQueryParameters3D.create(ray_start, ray_end, collision_layer)
		var excludes = []
		if launch_hand and is_instance_valid(launch_hand.current_target_node):
			var target = launch_hand.current_target_node
			if target is CollisionObject3D:
				excludes.append(target.get_rid())
				
		if player is CollisionObject3D:
			excludes.append(player.get_rid())
			
		query.exclude = excludes
		var result = space_state.intersect_ray(query)
		
		if not result.is_empty():
			var push_distance = cable_radius + surface_offset
			var wrap_point = result.position + (result.normal * push_distance)
			
			if wrap_point.distance_to(from) > 0.01 and wrap_point.distance_to(to) > 0.01:
				rope_points.insert(i + 1, wrap_point)
				rope_normals.insert(i + 1, result.normal) 
				return
		i += 1

func handle_unwrapping() -> void:
	if rope_points.size() <= 2:
		return
		
	var i = 1
	while i < rope_points.size() - 1:
		var prev = rope_points[i - 1]
		var curr = rope_points[i]
		var next = rope_points[i + 1]
		var normal = rope_normals[i]
		
		var dir_to_prev = (prev - curr).normalized()
		var dir_to_next = (next - curr).normalized()
		var pull_dir = (dir_to_prev + dir_to_next).normalized()
		
		if pull_dir.dot(normal) > 0.05:
			rope_points.remove_at(i)
			rope_normals.remove_at(i)
			continue 
			
		i += 1

func get_cable_length() -> float:
	var total: float = 0.0
	for i in range(rope_points.size() - 1):
		total += rope_points[i].distance_to(rope_points[i + 1])
	return total

func apply_shared_tension(p_player: CharacterBody3D) -> void:
	if not p_player or launch_hand.current_state != launch_hand.HandState.ATTACHED:
		return
		
	var target = launch_hand.current_target_node
	if target and target.get("is_swingable"):
		return

	var active_anchor = rope_points[1] if rope_points.size() > 1 else launch_hand.global_position
	var remaining_budget = cable_manager.get_remaining_length_for(self) if cable_manager else 30.0
	var my_wrapped_length = get_cable_length() - p_player.global_position.distance_to(active_anchor)
	var max_allowed_dist = max(0.1, remaining_budget - my_wrapped_length)

	if p_player.is_on_floor():
		var dy = abs(p_player.global_position.y - active_anchor.y)
		if max_allowed_dist > dy:
			var max_r_xz = sqrt(max_allowed_dist * max_allowed_dist - dy * dy)
			var anchor_xz = Vector2(active_anchor.x, active_anchor.z)
			var player_xz = Vector2(p_player.global_position.x, p_player.global_position.z)
			var dir_xz = player_xz - anchor_xz
			var dist_xz = dir_xz.length()
			
			if dist_xz >= max_r_xz - 0.05 and dist_xz > 0.001:
				var away_dir_3d = Vector3(dir_xz.x, 0, dir_xz.y).normalized()
				
				# Strip outward velocity before move_and_slide is executed
				if p_player.velocity.dot(away_dir_3d) > 0:
					p_player.velocity -= p_player.velocity.project(away_dir_3d)
				if "walk_vel" in p_player and p_player.walk_vel.dot(away_dir_3d) > 0:
					p_player.walk_vel -= p_player.walk_vel.project(away_dir_3d)
				
				if dist_xz > max_r_xz:
					var clamped_xz = anchor_xz + (dir_xz / dist_xz) * max_r_xz
					p_player.global_position.x = clamped_xz.x
					p_player.global_position.z = clamped_xz.y
	else:
		var to_player = p_player.global_position - active_anchor
		var dist = to_player.length()
		if dist >= max_allowed_dist - 0.05 and dist > 0.001:
			var dir_away = to_player / dist
			
			if p_player.velocity.dot(dir_away) > 0:
				p_player.velocity -= p_player.velocity.project(dir_away)
			if "walk_vel" in p_player and p_player.walk_vel.dot(dir_away) > 0:
				p_player.walk_vel -= p_player.walk_vel.project(dir_away)

			if dist > max_allowed_dist:
				p_player.global_position = active_anchor + (dir_away * max_allowed_dist)

func render_rope() -> void:
	var final_points = []
	for i in range(rope_points.size() - 1):
		var from = rope_points[i]
		var to = rope_points[i + 1]
		var distance = from.distance_to(to)
		
		for j in range(visual_segments_per_section):
			var t = float(j) / visual_segments_per_section
			var lerped_pos = from.lerp(to, t)
			var droop = sin(t * PI) * distance * sag_amount
			var sag_offset = Vector3.DOWN * droop
			final_points.append(lerped_pos + sag_offset)
			
	final_points.append(rope_points[rope_points.size() - 1])
	generate_tube_mesh(final_points)

func generate_tube_mesh(points: Array) -> void:
	if points.size() < 2:
		return
		
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	for i in range(points.size()):
		var forward = Vector3.FORWARD
		if i == points.size() - 1:
			forward = points[i] - points[i - 1]
		else:
			forward = points[i + 1] - points[i]
			
		forward = forward.normalized()
		var right = forward.cross(Vector3.UP)
		if right.is_zero_approx():
			right = forward.cross(Vector3.FORWARD)
		right = right.normalized()
		var up = forward.cross(right).normalized()
		
		for j in range(radial_segments):
			var angle = (float(j) / radial_segments) * TAU
			var local_pt = to_local(points[i])
			var local_right = global_transform.basis.inverse() * right
			var local_up = global_transform.basis.inverse() * up
			var offset = (cos(angle) * local_right * cable_radius) + (sin(angle) * local_up * cable_radius)
			st.add_vertex(local_pt + offset)
			
	for i in range(points.size() - 1):
		for j in range(radial_segments):
			var current = i * radial_segments + j
			var next_rad = i * radial_segments + ((j + 1) % radial_segments)
			var next_seg = current + radial_segments
			var next_seg_next = next_rad + radial_segments
			
			st.add_index(current)
			st.add_index(next_seg)
			st.add_index(next_rad)
			
			st.add_index(next_rad)
			st.add_index(next_seg)
			st.add_index(next_seg_next)
			
	st.generate_normals()
	mesh_instance.mesh = st.commit()

@tool
extends EditorScript

func _run():
	# 1. Point this to the root parent node containing your ground + mountain meshes
	var world_root = get_scene().get_node(".") 
	var grid_res: int = 513 # Increased resolution (513x513 or 1025x1025 for huge worlds)
	
	if not world_root:
		print("Root terrain node not found!")
		return

	# Collect all visual meshes and build temporary colliders if missing
	var mesh_nodes: Array[MeshInstance3D] = []
	var combined_aabb = _gather_meshes_and_colliders(world_root, mesh_nodes)
	
	if mesh_nodes.is_empty():
		print("No MeshInstance3D nodes found!")
		return

	var start_pos = combined_aabb.position
	var size = combined_aabb.size
	
	# Start rays 1000 units ABOVE the highest mountain peak
	var ray_start_y = combined_aabb.end.y + 1000.0
	var ray_end_y = combined_aabb.position.y - 500.0
	
	var space_state = world_root.get_world_3d().direct_space_state
	var heightmap_data = PackedFloat32Array()
	heightmap_data.resize(grid_res * grid_res)
	
	print("Sampling terrain and mountain heights...")
	for z in range(grid_res):
		for x in range(grid_res):
			var sample_x = start_pos.x + (float(x) / (grid_res - 1)) * size.x
			var sample_z = start_pos.z + (float(z) / (grid_res - 1)) * size.z
			
			var ray_from = Vector3(sample_x, ray_start_y, sample_z)
			var ray_to = Vector3(sample_x, ray_end_y, sample_z)
			
			var query = PhysicsRayQueryParameters3D.create(ray_from, ray_to)
			var result = space_state.intersect_ray(query)
			
			var height = start_pos.y
			if result:
				height = result.position.y
				
			heightmap_data[z * grid_res + x] = height

	# Build and save HeightMapShape3D
	var h_shape = HeightMapShape3D.new()
	h_shape.map_width = grid_res
	h_shape.map_depth = grid_res
	h_shape.map_data = heightmap_data
	
	ResourceSaver.save(h_shape, "res://full_world_heightmap.res")
	print("HeightMapShape3D successfully generated with mountains!")

func _gather_meshes_and_colliders(node: Node, mesh_list: Array[MeshInstance3D]) -> AABB:
	var total_aabb = AABB()
	var first_mesh = true
	
	for child in node.get_children(true):
		if child is MeshInstance3D and child.visible:
			mesh_list.append(child)
			
			# Generate a temporary static collider if the mesh doesn't have one
			if not _has_static_body_child(child):
				child.create_trimesh_collision()
			
			var mesh_aabb = child.global_transform * child.get_aabb()
			if first_mesh:
				total_aabb = mesh_aabb
				first_mesh = false
			else:
				total_aabb = total_aabb.merge(mesh_aabb)
				
		if child.get_child_count() > 0:
			var child_aabb = _gather_meshes_and_colliders(child, mesh_list)
			if child_aabb.size != Vector3.ZERO:
				if first_mesh:
					total_aabb = child_aabb
					first_mesh = false
				else:
					total_aabb = total_aabb.merge(child_aabb)
					
	return total_aabb

func _has_static_body_child(node: Node) -> bool:
	for c in node.get_children():
		if c is StaticBody3D:
			return true
	return false

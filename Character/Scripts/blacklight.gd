extends SpotLight3D

func _ready() -> void:
	# Force preview mode OFF when playing the game, keep ON when in editor
	if not Engine.is_editor_hint():
		RenderingServer.global_shader_parameter_set("uv_is_editor", 0.0)
	else:
		RenderingServer.global_shader_parameter_set("uv_is_editor", 1.0)

func _process(_delta: float) -> void:
	# If this light or any parent node is hidden, disable the UV beam completely
	if not is_visible_in_tree():
		RenderingServer.global_shader_parameter_set("uv_light_range", 0.0)
		return

	# Update light transform parameters
	RenderingServer.global_shader_parameter_set("uv_light_pos", global_position)
	
	var forward_dir: Vector3 = -global_transform.basis.z.normalized()
	RenderingServer.global_shader_parameter_set("uv_light_dir", forward_dir)
	
	var half_angle_rad: float = deg_to_rad(spot_angle * 0.5)
	RenderingServer.global_shader_parameter_set("uv_light_angle_cos", cos(half_angle_rad))
	
	RenderingServer.global_shader_parameter_set("uv_light_range", spot_range)

@tool
class_name BoneRemapper
extends SkeletonModifier3D

enum TransformMode { ROTATION, POSITION, BOTH }

@export var bone_name: String = ""
@export var mode: TransformMode = TransformMode.ROTATION

@export_group("Axis Mapping")
@export_enum("X", "Y", "Z") var source_axis: String = "Y" # Axis currently going left/right
@export_enum("X", "Y", "Z") var target_axis: String = "X" # Axis you want going forward/backward
@export var switch_axes: bool = true # Swaps source axis movement into target axis

@export_group("Modifiers")
@export var invert: bool = false
@export var multiplier: float = 1.0


func _process_modification() -> void:
	var skeleton: Skeleton3D = get_skeleton()
	if not skeleton or bone_name == "":
		return

	var bone_idx: int = skeleton.find_bone(bone_name)
	if bone_idx == -1:
		return

	var pose: Transform3D = skeleton.get_bone_pose(bone_idx)

	match mode:
		TransformMode.ROTATION:
			pose.basis = Basis.from_euler(_remap_vector(pose.basis.get_euler()))
		TransformMode.POSITION:
			pose.origin = _remap_vector(pose.origin)
		TransformMode.BOTH:
			pose.basis = Basis.from_euler(_remap_vector(pose.basis.get_euler()))
			pose.origin = _remap_vector(pose.origin)

	skeleton.set_bone_pose(bone_idx, pose)


func _remap_vector(vec: Vector3) -> Vector3:
	# 1. Extract value from source axis
	var val: float = 0.0
	match source_axis:
		"X": val = vec.x
		"Y": val = vec.y
		"Z": val = vec.z

	if invert:
		val = -val

	val *= multiplier
	var new_vec: Vector3 = vec

	# 2. Swap axes if enabled
	if switch_axes:
		# Zero out old axis
		if source_axis == "X": new_vec.x = 0.0
		elif source_axis == "Y": new_vec.y = 0.0
		elif source_axis == "Z": new_vec.z = 0.0

		# Route to target axis
		if target_axis == "X": new_vec.x = val
		elif target_axis == "Y": new_vec.y = val
		elif target_axis == "Z": new_vec.z = val
	else:
		# Just update the source axis directly with invert/multiplier
		if source_axis == "X": new_vec.x = val
		elif source_axis == "Y": new_vec.y = val
		elif source_axis == "Z": new_vec.z = val

	return new_vec

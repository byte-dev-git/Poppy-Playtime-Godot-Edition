@tool
extends SkeletonModifier3D
class_name BoneMultiModifier

# =============================================
# 1. LEAN (tilt based on camera rotation speed)
# =============================================
@export_group("Lean")
@export var lean_enabled: bool = true
@export var lean_bone: String = "Spine":
	set(val):
		lean_bone = val
		_update_bone_index(0)
@export var lean_invert: bool = false
@export var lean_intensity: float = 0.05
@export var lean_speed: float = 5.0
@export var lean_max_angle_deg: float = 15.0

# --- Additional lean along pitch axis ---
@export var lean_pitch_enabled: bool = false
@export var lean_pitch_invert: bool = false
@export var lean_pitch_intensity: float = 0.05
@export var lean_pitch_speed: float = 5.0
@export var lean_pitch_max_angle_deg: float = 10.0

@export var lean_inertia_enabled: bool = false
@export var lean_inertia_stiffness: float = 10.0
@export var lean_inertia_damping: float = 2.0

@export var lean_pitch_inertia_enabled: bool = false
@export var lean_pitch_inertia_stiffness: float = 10.0
@export var lean_pitch_inertia_damping: float = 2.0

# =============================================
# 2. LOOK AT (look towards target)
# =============================================
@export_group("LookAt")
@export var lookat_enabled: bool = true
@export var lookat_bone: String = "Head":
	set(val):
		lookat_bone = val
		_update_bone_index(1)
@export var lookat_target: Node3D
@export var lookat_limit_y_deg: float = 70.0
@export var lookat_limit_x_min_deg: float = -80.0
@export var lookat_limit_x_max_deg: float = 80.0
@export var lookat_rotation_offset: Vector3 = Vector3.ZERO
@export var lookat_target_offset: Vector3 = Vector3.ZERO
@export var lookat_keep_z: bool = false
@export var lookat_smoothness: float = 5.0
@export var lookat_influence: float = 1.0

# =============================================
# 3. ATTACH (attach node to bone)
# =============================================
@export_group("Attach")
@export var attach_enabled: bool = true
@export var attach_bone: String = "RightHand":
	set(val):
		attach_bone = val
		_update_bone_index(2)
@export var attach_target: Node3D
@export var attach_move_self: bool = false
@export var attach_position_offset: Vector3 = Vector3.ZERO
@export var attach_rotation_offset: Vector3 = Vector3.ZERO

# ---- Internal Variables ----
var _lean_angle: float = 0.0
var _lean_pitch_angle: float = 0.0
var _lean_velocity: float = 0.0
var _lean_pitch_velocity: float = 0.0
var _prev_camera_yaw: float = 0.0
var _prev_camera_pitch: float = 0.0
var _lookat_lerped_target: Vector3 = Vector3.ZERO
var _lookat_actual_influence: float = 0.0

# ---- Bone Indices ----
var _lean_bone_idx: int = -1
var _lookat_bone_idx: int = -1
var _attach_bone_idx: int = -1

func _ready():
	set_active(true)
	_refresh_bone_indices()
	_lookat_lerped_target = Vector3.ZERO
	_lean_angle = 0.0
	_lean_pitch_angle = 0.0
	_prev_camera_yaw = 0.0
	_prev_camera_pitch = 0.0
	_lookat_actual_influence = 0.0

func _update_bone_index(idx: int):
	var skeleton = get_skeleton()
	if skeleton:
		match idx:
			0: _lean_bone_idx = skeleton.find_bone(lean_bone)
			1: _lookat_bone_idx = skeleton.find_bone(lookat_bone)
			2: _attach_bone_idx = skeleton.find_bone(attach_bone)

func _refresh_bone_indices():
	var sk = get_skeleton()
	if sk:
		_lean_bone_idx = sk.find_bone(lean_bone)
		_lookat_bone_idx = sk.find_bone(lookat_bone)
		_attach_bone_idx = sk.find_bone(attach_bone)

func _process_modification():
	var sk = get_skeleton()
	if not sk: return

	var delta = get_process_delta_time()
	delta = min(delta, 0.05)

	# --- LEAN ---
	if lean_enabled and _lean_bone_idx != -1:
		_update_lean(delta, sk)

	# --- LOOK AT ---
	if lookat_enabled and _lookat_bone_idx != -1:
		_update_lookat(delta, sk)

	# --- ATTACH ---
	if attach_enabled and _attach_bone_idx != -1:
		_update_attach(sk)

# ===================== LEAN =====================
func _update_lean(delta: float, sk: Skeleton3D):
	var cam = get_viewport().get_camera_3d()
	if not cam: return

	# --- Yaw Lean (Z axis) ---
	var yaw = cam.global_rotation.y
	var dy = yaw - _prev_camera_yaw
	if dy > PI: dy -= TAU
	elif dy < -PI: dy += TAU
	_prev_camera_yaw = yaw

	var max_lean = deg_to_rad(lean_max_angle_deg)
	var target = clamp(-dy * lean_intensity, -max_lean, max_lean)

	if lean_inertia_enabled:
		var force = lean_inertia_stiffness * (target - _lean_angle) - lean_inertia_damping * _lean_velocity
		_lean_velocity += force * delta
		_lean_angle += _lean_velocity * delta
	else:
		_lean_angle = lerp(_lean_angle, target, lean_speed * delta)

	# --- Pitch Lean (X axis) ---
	if lean_pitch_enabled:
		var pitch = cam.global_rotation.x
		var dx = pitch - _prev_camera_pitch
		if dx > PI: dx -= TAU
		elif dx < -PI: dx += TAU
		_prev_camera_pitch = pitch

		var max_pitch = deg_to_rad(lean_pitch_max_angle_deg)
		var pitch_target = clamp(dx * lean_pitch_intensity, -max_pitch, max_pitch)

		if lean_pitch_inertia_enabled:
			var force_p = lean_pitch_inertia_stiffness * (pitch_target - _lean_pitch_angle) - lean_pitch_inertia_damping * _lean_pitch_velocity
			_lean_pitch_velocity += force_p * delta
			_lean_pitch_angle += _lean_pitch_velocity * delta
		else:
			_lean_pitch_angle = lerp(_lean_pitch_angle, pitch_target, lean_pitch_speed * delta)

	# --- Apply rotations to bone pose ---
	var pose = sk.get_bone_pose(_lean_bone_idx)

	var lean_z = -_lean_angle if lean_invert else _lean_angle
	if abs(lean_z) > 0.0001:
		var quat_z = Quaternion(Vector3(0, 0, 1), lean_z)
		pose.basis = pose.basis * Basis(quat_z)

	if lean_pitch_enabled:
		var pitch_final = -_lean_pitch_angle if lean_pitch_invert else _lean_pitch_angle
		if abs(pitch_final) > 0.0001:
			var quat_y = Quaternion(Vector3(0, 1, 0), pitch_final)
			pose.basis = pose.basis * Basis(quat_y)

	sk.set_bone_pose(_lean_bone_idx, pose)

# ===================== LOOK AT =====================
func _update_lookat(delta: float, sk: Skeleton3D):
	var target_inf = lookat_influence if is_instance_valid(lookat_target) else 0.0
	_lookat_actual_influence = lerpf(_lookat_actual_influence, target_inf, 10.0 * delta)
	if _lookat_actual_influence < 0.001 and not lookat_target:
		return

	var bone_pose = sk.get_bone_pose(_lookat_bone_idx)
	var parent_idx = sk.get_bone_parent(_lookat_bone_idx)
	var parent_pose = sk.get_bone_global_pose(parent_idx) if parent_idx != -1 else Transform3D.IDENTITY

	var destination: Vector3
	if lookat_target:
		destination = lookat_target.global_transform * lookat_target_offset
	else:
		var bone_global_pose = sk.get_bone_global_pose(_lookat_bone_idx)
		destination = sk.global_transform * bone_global_pose.origin + (sk.global_transform.basis * bone_global_pose.basis).z * 2.0

	if _lookat_lerped_target == Vector3.ZERO:
		_lookat_lerped_target = destination
	_lookat_lerped_target = _lookat_lerped_target.lerp(destination, lookat_smoothness * delta)

	# Convert target location into the bone parent's local space
	var sk_inv = sk.global_transform.affine_inverse()
	var target_sk = sk_inv * _lookat_lerped_target
	var parent_inv = parent_pose.affine_inverse()
	var target_in_parent = parent_inv * target_sk
	var bone_local_origin = bone_pose.origin

	if target_in_parent.distance_to(bone_local_origin) < 0.001:
		return

	var dir = (target_in_parent - bone_local_origin).normalized()
	if not dir.is_finite():
		return

	var raw_y = atan2(dir.x, dir.z)
	var lim_y = deg_to_rad(lookat_limit_y_deg)
	var target_y = raw_y if abs(raw_y) <= lim_y else clamp(sin(raw_y) / sin(lim_y) * lim_y, -lim_y, lim_y)
	var target_x = clamp(asin(clamp(-dir.y, -1.0, 1.0)), deg_to_rad(lookat_limit_x_min_deg), deg_to_rad(lookat_limit_x_max_deg))

	var anim_rot = bone_pose.basis.get_rotation_quaternion()
	var anim_euler = anim_rot.get_euler()
	var target_z = -anim_euler.z if lookat_keep_z else anim_euler.z

	var look_rot = Quaternion.from_euler(Vector3(target_x, target_y, target_z))
	var off_rot = Quaternion.from_euler(
		Vector3(
			deg_to_rad(lookat_rotation_offset.x),
			deg_to_rad(lookat_rotation_offset.y),
			deg_to_rad(lookat_rotation_offset.z)
		)
	)
	var corrected_look = look_rot * off_rot

	var final_rot = anim_rot.slerp(corrected_look, _lookat_actual_influence)
	sk.set_bone_pose(_lookat_bone_idx, Transform3D(Basis(final_rot), bone_pose.origin))

# ===================== ATTACH =====================
func _update_attach(sk: Skeleton3D):
	var bone_global = sk.global_transform * sk.get_bone_global_pose(_attach_bone_idx)
	
	var b = Basis.IDENTITY
	b = b.rotated(Vector3.RIGHT, deg_to_rad(attach_rotation_offset.x))
	b = b.rotated(Vector3.UP, deg_to_rad(attach_rotation_offset.y))
	b = b.rotated(Vector3.FORWARD, deg_to_rad(attach_rotation_offset.z))
	var off = Transform3D(b, attach_position_offset)
	
	var final_xform = bone_global * off

	if attach_target:
		attach_target.global_transform = final_xform
	if attach_move_self:
		global_transform = final_xform

# =============================================
# AUTO-POPULATE BONE NAMES IN INSPECTOR
# =============================================
func _validate_property(property: Dictionary) -> void:
	var skeleton = get_skeleton()
	if not skeleton: return
	
	if property.name in ["lean_bone", "lookat_bone", "attach_bone"]:
		property.hint = PROPERTY_HINT_ENUM
		property.hint_string = skeleton.get_concatenated_bone_names()

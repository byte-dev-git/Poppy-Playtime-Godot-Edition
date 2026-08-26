@tool
extends Control

@export_group("Background Texture")
@export var bg_texture: Texture2D:                  # T_Radial_Fade_W_Center_3.jpg
	set(value):
		bg_texture = value
		queue_redraw()

@export var bg_texture_size: Vector2 = Vector2(600, 600):
	set(value):
		bg_texture_size = value
		queue_redraw()

@export_group("Selection Sector Glow")
@export var glow_gap: float = 12.0:                 # Distance/gap between red arc and start of glow
	set(value):
		glow_gap = value
		queue_redraw()

@export var inner_radius: float = 110.0:            # Where the red inner arc line sits
	set(value):
		inner_radius = value
		queue_redraw()

@export var outer_radius: float = 240.0:            # Outer limit of the radial fade
	set(value):
		outer_radius = value
		queue_redraw()

@export var selection_color_inner: Color = Color(1.0, 0.6, 0.1, 0.45): # Bright inner glow color
	set(value):
		selection_color_inner = value
		queue_redraw()

@export var selection_color_outer: Color = Color(1.0, 0.6, 0.1, 0.0):  # Outer fade color (0 opacity)
	set(value):
		selection_color_outer = value
		queue_redraw()

@export_group("Red Arc Outline")
@export var red_arc_color: Color = Color(0.95, 0.15, 0.15, 1.0): # Red inner border
	set(value):
		red_arc_color = value
		queue_redraw()

@export var red_arc_width: float = 5.0:             # Red line thickness
	set(value):
		red_arc_width = value
		queue_redraw()

@export var slice_gap_degrees: float = 0.0:         # Gap between options (set to 0 for full slices)
	set(value):
		slice_gap_degrees = value
		queue_redraw()

@export var show_slice_dividers: bool = false:      # Side border lines along slice edges
	set(value):
		show_slice_dividers = value
		queue_redraw()

@export_group("Layout")
@export var deadzone_radius: float = 75.0:          # Center deadzone radius
	set(value):
		deadzone_radius = value
		queue_redraw()

@export var icon_distance: float = 180.0:           # Distance to hand icons
	set(value):
		icon_distance = value
		queue_redraw()

@export var icon_size: Vector2 = Vector2(90, 90):   # Size of hand icons
	set(value):
		icon_size = value
		queue_redraw()

@export_group("References")
@export var right_hand: Node3D

@onready var label: Label = $"../Label"
@onready var animation_player: AnimationPlayer = $"../AnimationPlayer"
@onready var bp_player: CharacterBody3D = $"../../.."

var options: Array[Dictionary] = []
var selection: int = -1
var prev_selection: int = -1
var current_mouse_angle: float = -PI / 2.0


func _ready() -> void:
	if not Engine.is_editor_hint():
		visible = false


func _unhandled_input(_event: InputEvent) -> void:
	if Engine.is_editor_hint() or not right_hand:
		return

	if Input.is_action_just_pressed("hand_wheel"):
		if bp_player.swinging: return
		if not visible:
			open_wheel()
			
	elif Input.is_action_just_released("hand_wheel"):
		if visible:
			close_wheel()


func open_wheel() -> void:
	$"../SwSfxModalPopUp".play()
	options.clear()
	selection = -1
	
	if not right_hand or not "hands" in right_hand:
		return
		
	var hand_scenes = right_hand.hands
	for i in range(hand_scenes.size()):
		var hand_instance = hand_scenes[i].instantiate()
		if hand_instance.name == "None":
			hand_instance.queue_free()
			continue
			
		var hand_info = hand_instance.get_node_or_null("HandInfo")
		if hand_info and hand_info.get("icon"):
			var display_name = hand_info.hand_name if "hand_name" in hand_info else hand_instance.name
			options.append({
				"name": display_name,
				"texture": hand_info.icon,
				"hand_int": i
			})
		hand_instance.queue_free()

	if options.is_empty():
		return

	if bp_player and bp_player.has_method("capture_mouse"):
		bp_player.capture_mouse(false, true)

	show()
	
	if animation_player and animation_player.has_animation("in"):
		animation_player.play("in")


func close_wheel() -> void:
	$"../SwSfxClosingMenu".play()
	
	if not options.is_empty() and selection >= 0 and selection < options.size():
		var target_hand_int = options[selection]["hand_int"]
		var current_hand_int = right_hand.current_hand
		
		if target_hand_int != current_hand_int:
			if right_hand.has_method("queue_test") and right_hand.queue_test(target_hand_int):
				right_hand.switch_hand(1, target_hand_int)

	if bp_player and bp_player.has_method("capture_mouse"):
		bp_player.capture_mouse(true, true)

	if animation_player and animation_player.has_animation("out"):
		animation_player.play("out")
		await animation_player.animation_finished

	hide()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()
		return

	if not visible or options.is_empty():
		return

	var old_selection = selection
	var mouse_pos = get_local_mouse_position()
	var mouse_dist = mouse_pos.length()

	if mouse_dist < deadzone_radius:
		selection = -1
		if label:
			label.text = ""
	else:
		current_mouse_angle = mouse_pos.angle()
		var num_options = options.size()
		var slice = TAU / num_options
		var normalized_angle = fposmod(current_mouse_angle + (PI / 2.0) + (slice / 2.0), TAU)
		selection = clampi(int(normalized_angle / slice), 0, num_options - 1)

# Play sound if selection changed to a new valid hand option
	if selection != old_selection and selection != -1:
		$"../SwSfxHandSwapWheel".play()

		if label and selection >= 0:
			label.text = options[selection]["name"].to_upper()

	prev_selection = selection
	queue_redraw()


func _draw() -> void:
	var display_options = options
	var active_selection = selection

	# Editor preview fallback
	if Engine.is_editor_hint() and display_options.is_empty():
		display_options = [
			{"name": "RED HAND", "texture": bg_texture, "hand_int": 0},
			{"name": "PRESSURIZED HAND", "texture": bg_texture, "hand_int": 1}
		]
		active_selection = 0

	if display_options.is_empty():
		return

	# 1. Base Dark Disc Background
	if bg_texture:
		var bg_rect = Rect2(-bg_texture_size / 2.0, bg_texture_size)
		draw_texture_rect(bg_texture, bg_rect, false)

	var num_options = display_options.size()
	var slice = TAU / num_options

	# 2. Draw Glow + Red Arc Line
	if active_selection != -1:
		var active_center_angle = -PI / 2.0 + (active_selection * slice)
		
		# Optional slice padding
		var half_gap = deg_to_rad(slice_gap_degrees / 2.0)
		var arc_start = active_center_angle - (slice / 2.0) + half_gap
		var arc_end = active_center_angle + (slice / 2.0) - half_gap

		if arc_start < arc_end:
			# A. Draw Orange Selection Glow starting OFFSET from the red arc by glow_gap
			var glow_start_radius = inner_radius + glow_gap
			var steps = 32

			for i in range(steps):
				var t1 = float(i) / steps
				var t2 = float(i + 1) / steps
				var a1 = lerp(arc_start, arc_end, t1)
				var a2 = lerp(arc_start, arc_end, t2)

				var quad_pts = PackedVector2Array([
					Vector2.from_angle(a1) * glow_start_radius,
					Vector2.from_angle(a2) * glow_start_radius,
					Vector2.from_angle(a2) * outer_radius,
					Vector2.from_angle(a1) * outer_radius
				])
				var quad_cols = PackedColorArray([
					selection_color_inner,
					selection_color_inner,
					selection_color_outer,
					selection_color_outer
				])
				draw_polygon(quad_pts, quad_cols)

			# B. Draw Inner Red Arc Line at inner_radius
			draw_arc(Vector2.ZERO, inner_radius, arc_start, arc_end, 32, red_arc_color, red_arc_width, true)

			# C. Optional Side Border Lines
			if show_slice_dividers:
				var p1_in = Vector2.from_angle(arc_start) * inner_radius
				var p1_out = Vector2.from_angle(arc_start) * outer_radius
				draw_line(p1_in, p1_out, red_arc_color, 2.0, true)

				var p2_in = Vector2.from_angle(arc_end) * inner_radius
				var p2_out = Vector2.from_angle(arc_end) * outer_radius
				draw_line(p2_in, p2_out, red_arc_color, 2.0, true)

	# 3. Hand Icons
	for i in range(num_options):
		var option_angle = -PI / 2.0 + (i * slice)
		var icon_center = Vector2.from_angle(option_angle) * icon_distance
		var draw_rect = Rect2(icon_center - (icon_size / 2.0), icon_size)
		var texture: Texture2D = display_options[i]["texture"]

		if texture:
			draw_texture_rect(texture, draw_rect, false, Color.WHITE)

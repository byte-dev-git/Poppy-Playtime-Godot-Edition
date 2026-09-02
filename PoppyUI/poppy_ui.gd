extends CanvasLayer



@onready var fps_counter: Label = $FPSCounter

var show_fps_label: bool = true

func show_fps(value: bool, delta: float):
	#if value:
		#fps_counter.show()
	#else: fps_counter.hide()
	fps_counter.text =  "%d FPS" % Engine.get_frames_per_second()

func _process(delta: float) -> void:
	#if show_fps_label:
		#show_fps(true, delta)
	show_fps(false, delta)

#func _unhandled_input(event: InputEvent) -> void:
	#if event is InputEventKey and event.pressed:
		#if event.keycode == KEY_H:
			#if $Crosshair.visible == true:
				#$Crosshair.visible = false
				#show_fps_label = false
			#else: 
				#show_fps_label = true
				#$Crosshair.visible = true

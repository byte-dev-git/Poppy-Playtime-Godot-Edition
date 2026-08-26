extends CanvasLayer



@onready var fps_counter: Label = $FPSCounter


func show_fps(value: bool, delta: float):
	if value:
		fps_counter.show()
	else: fps_counter.hide()
	
	fps_counter.text =  "%d FPS" % Engine.get_frames_per_second()

func _process(delta: float) -> void:
	show_fps(true, delta)

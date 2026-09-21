extends Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var step := 18
	for y in range(0, int(size.y), step):
		for x in range(0, int(size.x), step):
			var value := 0.175 if (x / step + y / step) % 2 == 0 else 0.19
			draw_rect(Rect2(x, y, step, step), Color(value, value + 0.008, value + 0.018))

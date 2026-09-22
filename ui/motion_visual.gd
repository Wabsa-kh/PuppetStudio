extends Control

var app
var timeline := false

func _ready() -> void:
	custom_minimum_size = Vector2(220, 95)
	mouse_filter = Control.MOUSE_FILTER_STOP if timeline else Control.MOUSE_FILTER_IGNORE
	tooltip_text = "Click the ruler to scrub the selected layer's motion clip." if timeline else "Motion preview: horizontal and vertical waves. The moving dot shows the current phase."

func _process(_delta: float) -> void:
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if timeline and event is InputEventMouseButton and event.pressed and app.selected_layer >= 0:
		var layer: Dictionary = app.document.data.layers[app.selected_layer]
		var duration := float(layer.get("clip", {}).get("duration", 2))
		app.key_time = clampf((event.position.x - 10) / (size.x - 20), 0, 1) * duration
		app.avatar.clip_time = app.key_time
		app.avatar.clips_playing = false
		app.avatar.clips_preview = true
		app._refresh_inspector()

func _draw() -> void:
	draw_style_box(app._box("1b1e23", "424953"), Rect2(Vector2.ZERO, size))
	for x in range(1, 8): draw_line(Vector2(size.x * x / 8, 8), Vector2(size.x * x / 8, size.y - 8), Color("303640"))
	draw_line(Vector2(8, size.y / 2), Vector2(size.x - 8, size.y / 2), Color("46505a"))
	if app.selected_layer < 0: return
	var layer: Dictionary = app.document.data.layers[app.selected_layer]
	if timeline:
		var clip: Dictionary = layer.get("clip", {"duration": 2.0, "keys": []})
		for key in clip.get("keys", []):
			var pos := Vector2(10 + float(key.time) / float(clip.duration) * (size.x - 20), size.y / 2)
			draw_colored_polygon(PackedVector2Array([pos + Vector2(0, -6), pos + Vector2(6, 0), pos + Vector2(0, 6), pos + Vector2(-6, 0)]), Color("d3bf88"))
		var local_time: float = fposmod(app.avatar.clip_time, float(clip.duration)) if app.avatar.clips_playing and clip.get("loop", true) else clampf(app.avatar.clip_time, 0, float(clip.duration))
		var playhead := 10 + local_time / float(clip.duration) * (size.x - 20)
		draw_line(Vector2(playhead, 8), Vector2(playhead, size.y - 8), Color("a9c88d"), 2)
		draw_string(ThemeDB.fallback_font, Vector2(12, size.y - 9), "0 s", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("b9c0c8"))
		draw_string(ThemeDB.fallback_font, Vector2(size.x - 70, size.y - 9), "%.2f s" % clip.duration, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("b9c0c8"))
	else:
		for axis in range(2):
			var amp := float(layer.get("sway" if axis == 0 else "float_y", 0))
			var speed := float(layer.get("sway_speed" if axis == 0 else "sway_speed_y", 2.1))
			var points := PackedVector2Array()
			for i in range(100):
				points.append(Vector2(10 + (size.x - 20) * i / 99, size.y / 2 - sin(i / 99.0 * 4 * speed) * minf(amp, 32)))
			draw_polyline(points, Color("a8c98a") if axis == 0 else Color("7dacc8"), 1.5, true)
		var phase := fposmod(app.avatar.clock, 4) / 4
		draw_circle(Vector2(10 + phase * (size.x - 20), size.y / 2), 3, Color("e0d9c2"))

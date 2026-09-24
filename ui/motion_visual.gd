extends Control

var app
var timeline := false
var dragging := false
var hovered_time := -1.0

const LEFT_PAD := 18.0
const RIGHT_PAD := 18.0
const RULER_TOP := 29.0
const TRACK_Y := 67.0

func _ready() -> void:
	custom_minimum_size = Vector2(300, 112 if timeline else 95)
	mouse_filter = Control.MOUSE_FILTER_STOP if timeline else Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_ALL if timeline else Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if timeline else Control.CURSOR_ARROW
	tooltip_text = "Drag anywhere on the timeline to move the playhead. Click a diamond to inspect that saved pose." if timeline else "Movement preview: green shows horizontal sway and blue shows vertical float."

func _process(_delta: float) -> void:
	queue_redraw()

func duration() -> float:
	if app == null or app.selected_layer < 0 or app.selected_layer >= app.document.data.layers.size():
		return 1.0
	return maxf(0.01, float(app.document.data.layers[app.selected_layer].get("clip", {}).get("duration", 2.0)))

func time_from_x(x: float) -> float:
	return clampf((x - LEFT_PAD) / maxf(1.0, size.x - LEFT_PAD - RIGHT_PAD), 0.0, 1.0) * duration()

func x_from_time(seconds: float) -> float:
	return LEFT_PAD + clampf(seconds / duration(), 0.0, 1.0) * maxf(1.0, size.x - LEFT_PAD - RIGHT_PAD)

func set_playhead(seconds: float) -> void:
	if app == null or app.selected_layer < 0:
		return
	app.key_time = clampf(seconds, 0.0, duration())
	app.avatar.clip_time = app.key_time
	app.avatar.clips_playing = false
	app.avatar.clips_preview = true
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if not timeline or app == null or app.selected_layer < 0:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			dragging = true
			grab_focus()
			set_playhead(time_from_x(event.position.x))
			accept_event()
		else:
			if dragging:
				set_playhead(time_from_x(event.position.x))
				dragging = false
				accept_event()
				app.call_deferred("_refresh_inspector")
	elif event is InputEventMouseMotion:
		hovered_time = time_from_x(event.position.x)
		if dragging:
			set_playhead(hovered_time)
			accept_event()
		queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
		set_playhead(app.key_time - 0.05)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		set_playhead(app.key_time + 0.05)
		accept_event()

func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		hovered_time = -1.0
		queue_redraw()

func _draw() -> void:
	if app == null:
		return
	draw_style_box(app._box("181b20", "454c55"), Rect2(Vector2.ZERO, size))
	if timeline:
		_draw_timeline()
	else:
		_draw_waves()

func _draw_timeline() -> void:
	var total := duration()
	var layer_name := "No part selected"
	var keys: Array = []
	var looped := false
	if app.selected_layer >= 0 and app.selected_layer < app.document.data.layers.size():
		var layer: Dictionary = app.document.data.layers[app.selected_layer]
		layer_name = str(layer.get("name", "Part"))
		var clip: Dictionary = layer.get("clip", {"duration": 2.0, "keys": []})
		keys = clip.get("keys", [])
		looped = bool(clip.get("loop", true))
	draw_string(ThemeDB.fallback_font, Vector2(LEFT_PAD, 20), layer_name + "  ·  " + str(keys.size()) + " saved poses", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("d6dbe1"))
	draw_string(ThemeDB.fallback_font, Vector2(size.x - 104, 20), "%05.2f s" % clampf(app.key_time, 0.0, total), HORIZONTAL_ALIGNMENT_RIGHT, 86, 12, Color("a9c88d"))
	var steps := clampi(int(ceil(total * 2.0)), 4, 20)
	for i in range(steps + 1):
		var t := total * i / steps
		var x := x_from_time(t)
		var major := i % 2 == 0 or steps <= 6
		draw_line(Vector2(x, RULER_TOP), Vector2(x, TRACK_Y + (13 if major else 8)), Color("353b44"), 1.0)
		if major:
			draw_string(ThemeDB.fallback_font, Vector2(x - 15, 43), "%.1f" % t, HORIZONTAL_ALIGNMENT_CENTER, 30, 10, Color("8f9aa6"))
	draw_line(Vector2(LEFT_PAD, TRACK_Y), Vector2(size.x - RIGHT_PAD, TRACK_Y), Color("606975"), 3.0, true)
	for key in keys:
		var pos := Vector2(x_from_time(float(key.get("time", 0.0))), TRACK_Y)
		draw_colored_polygon(PackedVector2Array([pos + Vector2(0, -8), pos + Vector2(8, 0), pos + Vector2(0, 8), pos + Vector2(-8, 0)]), Color("d5bb79"))
		draw_polyline(PackedVector2Array([pos + Vector2(0, -8), pos + Vector2(8, 0), pos + Vector2(0, 8), pos + Vector2(-8, 0), pos + Vector2(0, -8)]), Color("fff0bb"), 1.0)
	var local_time: float = fposmod(app.avatar.clip_time, total) if app.avatar.clips_playing and looped else clampf(app.avatar.clip_time, 0.0, total)
	var playhead := x_from_time(local_time)
	draw_line(Vector2(playhead, RULER_TOP - 2), Vector2(playhead, size.y - 12), Color("9fc879"), 2.0, true)
	draw_colored_polygon(PackedVector2Array([Vector2(playhead - 7, RULER_TOP - 2), Vector2(playhead + 7, RULER_TOP - 2), Vector2(playhead, RULER_TOP + 7)]), Color("9fc879"))
	if hovered_time >= 0.0 and not dragging:
		var hover_x := x_from_time(hovered_time)
		draw_line(Vector2(hover_x, 47), Vector2(hover_x, size.y - 12), Color("73808d80"), 1.0)
		draw_string(ThemeDB.fallback_font, Vector2(clampf(hover_x - 24, 4, size.x - 52), size.y - 4), "%.2f s" % hovered_time, HORIZONTAL_ALIGNMENT_CENTER, 48, 10, Color("aeb8c2"))
	draw_string(ThemeDB.fallback_font, Vector2(LEFT_PAD, size.y - 5), "Drag to scrub  ·  mouse wheel nudges 0.05 s", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("84909c"))

func _draw_waves() -> void:
	for x in range(1, 8):
		draw_line(Vector2(size.x * x / 8, 8), Vector2(size.x * x / 8, size.y - 8), Color("303640"))
	draw_line(Vector2(8, size.y / 2), Vector2(size.x - 8, size.y / 2), Color("46505a"))
	if app.selected_layer < 0:
		return
	var layer: Dictionary = app.document.data.layers[app.selected_layer]
	for axis in range(2):
		var amp := float(layer.get("sway" if axis == 0 else "float_y", 0))
		var speed := float(layer.get("sway_speed" if axis == 0 else "sway_speed_y", 2.1))
		var points := PackedVector2Array()
		for i in range(100):
			points.append(Vector2(10 + (size.x - 20) * i / 99, size.y / 2 - sin(i / 99.0 * 4 * speed) * minf(amp, 32)))
		draw_polyline(points, Color("a8c98a") if axis == 0 else Color("7dacc8"), 1.5, true)
	var phase := fposmod(app.avatar.clock, 4) / 4
	draw_circle(Vector2(10 + phase * (size.x - 20), size.y / 2), 3, Color("e0d9c2"))

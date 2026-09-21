extends Node2D

const PoseSolver = preload("res://core/pose_solver.gd")
var solver = PoseSolver.new()
var document
var expression := 0
var talking := false
var blinking := false
var clock := 0.0
var expression_clock := 0.0
var previous_expression := -1
var next_blink := 2.4
var blink_left := 0.0
var poses: Dictionary = {}
var motion_enabled := true
var pointer := Vector2.ZERO
var root_transform := Transform2D.IDENTITY
var layer_animation_start: Dictionary = {}
var last_visible: Dictionary = {}
var root_opacity := 1.0

func force_blink() -> void:
	blink_left = float(document.data.get("blink_duration", 0.14)) if document != null else 0.14

func reset_motion() -> void:
	solver.clear()
	poses.clear()
	layer_animation_start.clear()
	last_visible.clear()

func _process(delta: float) -> void:
	if document == null or document.data.is_empty():
		return
	clock += delta
	expression_clock += delta
	if previous_expression != expression:
		previous_expression = expression
		expression_clock = 0.0
	next_blink -= delta
	if next_blink <= 0.0:
		var minimum := float(document.data.get("blink_min", 2.5))
		var maximum := maxf(minimum, float(document.data.get("blink_max", 5.2)))
		next_blink = randf_range(minimum, maximum)
		if document.data.blink:
			force_blink()
	blink_left = maxf(0, blink_left - delta)
	blinking = blink_left > 0
	var amount := float(document.data.motion) if motion_enabled else 0.0
	var offset := Vector2(0, -absf(sin(clock * (10.0 if talking else 2.0))) * (9 if talking else 2) * amount)
	root_transform = Transform2D(deg_to_rad(float(document.data.get("base_rotation", 0))), Vector2.ONE * float(document.data.get("base_scale", 1)), 0, Vector2(256 + float(document.data.get("base_x", 0)), 256 + float(document.data.get("base_y", 0))) + offset)
	root_opacity = 1.0 if talking else 1.0 - float(document.data.get("idle_dim", 0.0))
	poses = solver.evaluate(document.data.layers, delta, clock, talking, blinking, amount, pointer)
	for layer in document.data.layers:
		var shown: bool = solver.visible.get(layer.id, false)
		if shown and not last_visible.get(layer.id, false):
			layer_animation_start[layer.id] = clock
		last_visible[layer.id] = shown
	queue_redraw()

func _draw() -> void:
	if document == null or document.data.expressions.is_empty():
		return
	var state: Dictionary = document.data.expressions[clampi(expression, 0, document.data.expressions.size() - 1)]
	var slot := "talk" if talking else "idle"
	if blinking:
		slot = "talk_blink" if talking else "blink"
	var id: String = state.get(slot, "")
	if id.is_empty():
		id = state.get("talk" if talking else "idle", "")
	if id.is_empty():
		id = state.idle
	var image: Texture2D = document.frame_texture(id, expression_clock if state.get("restart", false) else clock)
	if image != null:
		var fit := minf(440.0 / image.get_width(), 440.0 / image.get_height())
		var extent := image.get_size() * fit
		draw_set_transform_matrix(root_transform)
		draw_texture_rect(image, Rect2(Vector2(0, 9) - extent * 0.5, extent), false, Color(root_opacity, root_opacity, root_opacity, 1))
	for layer in document.data.layers:
		if not solver.visible.get(layer.id, false):
			continue
		var elapsed := clock - float(layer_animation_start.get(layer.id, 0))
		var tex: Texture2D = document.frame_texture(layer.image, elapsed, layer.get("loop", true))
		if tex == null:
			continue
		var columns := maxi(1, int(layer.frames))
		var rows := maxi(1, int(layer.get("rows", 1)))
		var count := columns * rows
		var frame := int(elapsed * float(layer.fps))
		frame = frame % count if layer.get("loop", true) else mini(frame, count - 1)
		var extent := Vector2(tex.get_width() / float(columns), tex.get_height() / float(rows))
		var source := Rect2(Vector2(frame % columns, frame / columns) * extent, extent)
		var pivot := Vector2(float(layer.get("pivot_x", 0)), float(layer.get("pivot_y", 0)))
		draw_set_transform_matrix(root_transform * poses.get(layer.id, Transform2D.IDENTITY))
		draw_texture_rect_region(tex, Rect2(-extent * 0.5 - pivot, extent), source, Color(root_opacity, root_opacity, root_opacity, solver.opacity.get(layer.id, 1.0)))
	draw_set_transform(Vector2.ZERO)

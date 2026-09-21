extends Node2D

const LayerCanvas = preload("res://runtime/layer_canvas.gd")
var canvases: Dictionary = {}
var hierarchy_signature := ""
var layer_toggles: Dictionary = {}

const MotionClip = preload("res://core/motion_clip.gd")
var hop := 0.0
var hop_velocity := 0.0
var was_talking := false
var last_costume := -1
var costume := -1
var clip_time := 0.0
var clips_playing := false
var clips_preview := false

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
	if clips_playing:
		clip_time += delta
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
	if (talking and not was_talking) or (costume != last_costume and document.data.get("bounce_on_costume", false)):
		hop_velocity = -float(document.data.get("bounce_force", 80.0))
	was_talking = talking
	last_costume = costume
	if hop < 0 or hop_velocity < 0:
		hop_velocity += float(document.data.get("bounce_gravity", 500.0)) * minf(delta, 0.05)
		hop += hop_velocity * minf(delta, 0.05)
		if hop >= 0:
			hop = 0.0
			hop_velocity = 0.0
	var amount := float(document.data.motion) if motion_enabled else 0.0
	var offset := Vector2(0, -absf(sin(clock * (10.0 if talking else 2.0))) * (9 if talking else 2) * amount)
	offset.y += hop * amount
	root_transform = Transform2D(deg_to_rad(float(document.data.get("base_rotation", 0))), Vector2.ONE * float(document.data.get("base_scale", 1)), 0, Vector2(256 + float(document.data.get("base_x", 0)), 256 + float(document.data.get("base_y", 0))) + offset)
	root_opacity = 1.0 if talking else 1.0 - float(document.data.get("idle_dim", 0.0))
	var costumes: Array = document.data.get("costumes", [])
	var outfit: Dictionary = costumes[costume].layers if costume >= 0 and costume < costumes.size() else {}
	var evaluated := MotionClip.layers_for_pose(document.data.layers, outfit, clip_time, clips_playing or clips_preview)
	for layer in evaluated:
		if layer_toggles.has(layer.id): layer.visible = layer_toggles[layer.id]
	poses = solver.evaluate(evaluated, delta, clock, talking, blinking, amount, pointer)
	for layer in document.data.layers:
		var shown: bool = solver.visible.get(layer.id, false)
		if shown and not last_visible.get(layer.id, false):
			layer_animation_start[layer.id] = clock
		last_visible[layer.id] = shown
		if not canvases.has(layer.id):
			var canvas := LayerCanvas.new()
			canvas.document = document
			add_child(canvas)
			canvases[layer.id] = canvas
		var canvas: Node2D = canvases[layer.id]
		canvas.visible = shown
		canvas.transform = root_transform * poses.get(layer.id, Transform2D.IDENTITY)
		if layer.get("ignore_bounce", false):
			canvas.position -= offset
		canvas.configure(layer, clock - float(layer_animation_start.get(layer.id, 0)), root_opacity, float(solver.opacity.get(layer.id, 1.0)))
	for id in canvases.keys():
		if not solver.index.has(id):
			for child in canvases[id].get_children():
				child.reparent(self, false)
			canvases[id].queue_free()
			canvases.erase(id)
	var signature := ""
	for layer in document.data.layers:
		signature += layer.id + ":" + layer.parent + str(layer.get("clip_children", false))
	if signature != hierarchy_signature:
		for canvas in canvases.values():
			if canvas.get_parent() != self: canvas.reparent(self, false)
		hierarchy_signature = signature
	for layer in document.data.layers:
		var canvas: Node2D = canvases[layer.id]
		var clip_parent := ""
		var ancestor: String = layer.parent
		while not ancestor.is_empty() and solver.index.has(ancestor):
			if solver.index[ancestor].get("clip_children", false):
				clip_parent = ancestor
				break
			ancestor = solver.index[ancestor].parent
		var desired: Node = self if clip_parent.is_empty() else canvases[clip_parent]
		if canvas.get_parent() != desired:
			canvas.reparent(desired, false)
		var world: Transform2D = root_transform * poses.get(layer.id, Transform2D.IDENTITY)
		if layer.get("ignore_bounce", false): world.origin -= offset
		if clip_parent.is_empty():
			canvas.transform = world
		else:
			var mask_world: Transform2D = root_transform * poses[clip_parent]
			if solver.index[clip_parent].get("ignore_bounce", false): mask_world.origin -= offset
			canvas.transform = mask_world.affine_inverse() * world
		desired.move_child(canvas, desired.get_child_count() - 1)
		canvas.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW if layer.get("clip_children", false) else CanvasItem.CLIP_CHILDREN_DISABLED
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
	draw_set_transform(Vector2.ZERO)

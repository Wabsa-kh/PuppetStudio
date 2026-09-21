extends Control

var app

func _process(_delta: float) -> void:
	queue_redraw()

func point(value: Vector2) -> Vector2:
	return app.preview_texture.position + value * app.preview_texture.size.x / 512.0

func _draw() -> void:
	if app == null or not app.rig_visible or app.view_tabs.selected == 2:
		return
	for layer in app.document.data.layers:
		var pose: Transform2D = app.avatar.root_transform * app.avatar.poses.get(layer.id, Transform2D.IDENTITY)
		var origin := point(pose.origin)
		if not layer.parent.is_empty() and app.avatar.poses.has(layer.parent):
			var parent_pose: Transform2D = app.avatar.root_transform * app.avatar.poses[layer.parent]
			draw_line(point(parent_pose.origin), origin, Color(0.65, 0.76, 0.55, 0.55), 1.0, true)
		draw_circle(origin, 3, Color("a4b78a"))
	if app.selected_layer < 0 or app.selected_layer >= app.document.data.layers.size():
		return
	var layer: Dictionary = app.document.data.layers[app.selected_layer]
	var texture: Texture2D = app.document.texture(layer.image)
	if texture == null:
		return
	var extent := texture.get_size() / Vector2(maxi(1, int(layer.frames)), maxi(1, int(layer.get("rows", 1))))
	var offset := -extent * 0.5 - Vector2(float(layer.get("pivot_x", 0)), float(layer.get("pivot_y", 0)))
	var pose: Transform2D = app.avatar.root_transform * app.avatar.poses.get(layer.id, Transform2D.IDENTITY)
	var corners := PackedVector2Array()
	for corner in [offset, offset + Vector2(extent.x, 0), offset + extent, offset + Vector2(0, extent.y), offset]:
		corners.append(point(pose * corner))
	draw_polyline(corners, Color("d9c486"), 1.5, true)
	var pivot := point(pose.origin)
	draw_line(pivot - Vector2(9, 0), pivot + Vector2(9, 0), Color("f2d997"), 2)
	draw_line(pivot - Vector2(0, 9), pivot + Vector2(0, 9), Color("f2d997"), 2)

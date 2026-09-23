extends Node2D

var document
var layer: Dictionary = {}
var elapsed := 0.0
var brightness := 1.0
var opacity := 1.0
var blend := -1

func configure(data: Dictionary, clock: float, dim: float, alpha: float) -> void:
	layer = data
	elapsed = clock
	brightness = dim
	opacity = alpha
	var next_blend := int(layer.get("blend", 0))
	if next_blend != blend:
		blend = next_blend
		var canvas_material := CanvasItemMaterial.new()
		canvas_material.blend_mode = blend
		material = canvas_material
	queue_redraw()

func _draw() -> void:
	if document == null or layer.is_empty():
		return
	var texture: Texture2D = document.frame_texture(layer.image, elapsed, layer.get("loop", true))
	if texture == null:
		return
	var columns := maxi(1, int(layer.frames))
	var rows := maxi(1, int(layer.get("rows", 1)))
	var count := columns * rows
	var frame := int(elapsed * float(layer.fps))
	frame = frame % count if layer.get("loop", true) else mini(frame, count - 1)
	var extent := Vector2(texture.get_width() / float(columns), texture.get_height() / float(rows))
	var source := Rect2(Vector2(frame % columns, frame / columns) * extent, extent)
	var pivot := Vector2(float(layer.get("pivot_x", 0)), float(layer.get("pivot_y", 0)))
	var tint := Color(str(layer.get("tint", "ffffff")))
	draw_texture_rect_region(texture, Rect2(-extent * 0.5 - pivot, extent), source, Color(tint.r * brightness, tint.g * brightness, tint.b * brightness, tint.a * opacity))

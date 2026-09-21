extends RefCounted

static func local_transform(layer: Dictionary) -> Transform2D:
	var size := Vector2(float(layer.get("scale_x", 1)), float(layer.get("scale_y", 1))) * float(layer.scale)
	if layer.get("flip_x", false): size.x *= -1
	if layer.get("flip_y", false): size.y *= -1
	return Transform2D(deg_to_rad(float(layer.rotation)), size, float(layer.get("skew", 0)), Vector2(float(layer.x), float(layer.y)))

static func rest_transform(layers: Array, id: String, visited: Dictionary = {}) -> Transform2D:
	if id.is_empty() or visited.has(id):
		return Transform2D.IDENTITY
	visited[id] = true
	for layer in layers:
		if layer.id == id:
			return rest_transform(layers, layer.parent, visited) * local_transform(layer)
	return Transform2D.IDENTITY

static func reparent(layers: Array, layer: Dictionary, parent: String) -> void:
	var world := rest_transform(layers, layer.id)
	var local := rest_transform(layers, parent).affine_inverse() * world
	layer.parent = parent
	layer.x = local.origin.x
	layer.y = local.origin.y
	layer.rotation = rad_to_deg(local.get_rotation())
	var size := local.get_scale()
	layer.scale = 1.0
	layer.scale_x = absf(size.x)
	layer.scale_y = absf(size.y)
	layer.flip_x = size.x < 0
	layer.flip_y = size.y < 0
	# Preserve shear introduced by a rotated, non-uniformly scaled parent.
	layer.skew = local.get_skew()

static func move_pivot(layer: Dictionary, delta: Vector2) -> void:
	var displacement := local_transform(layer).basis_xform(delta)
	layer.pivot_x = float(layer.get("pivot_x", 0)) + delta.x
	layer.pivot_y = float(layer.get("pivot_y", 0)) + delta.y
	layer.x += displacement.x
	layer.y += displacement.y

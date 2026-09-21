extends RefCounted

var transforms: Dictionary = {}
var velocities: Dictionary = {}
var angular_velocities: Dictionary = {}
var visible: Dictionary = {}
var opacity: Dictionary = {}
var index: Dictionary = {}
var resolved: Dictionary = {}
var time := 0.0
var step_seconds := 0.016
var speech := false
var blink := false
var amount := 1.0
var pointer := Vector2.ZERO

func clear() -> void:
	transforms.clear()
	velocities.clear()
	angular_velocities.clear()

func evaluate(layers: Array, delta: float, clock: float, talking: bool, blinking: bool, strength: float, mouse: Vector2 = Vector2.ZERO) -> Dictionary:
	index.clear()
	resolved.clear()
	time = clock
	step_seconds = clampf(delta, 0.0, 0.1)
	speech = talking
	blink = blinking
	amount = strength
	pointer = mouse
	for layer in layers:
		index[layer.id] = layer
	for layer in layers:
		_resolve(layer.id, {})
	for id in transforms.keys():
		if not index.has(id):
			transforms.erase(id)
			velocities.erase(id)
			angular_velocities.erase(id)
	return transforms

func _resolve(id: String, visiting: Dictionary) -> Transform2D:
	if resolved.has(id):
		return transforms[id]
	if visiting.has(id) or not index.has(id):
		return Transform2D.IDENTITY
	visiting[id] = true
	var layer: Dictionary = index[id]
	var parent := Transform2D.IDENTITY
	var parent_visible := true
	var parent_opacity := 1.0
	if not layer.parent.is_empty() and index.has(layer.parent):
		parent = _resolve(layer.parent, visiting)
		parent_visible = visible.get(layer.parent, true)
		parent_opacity = opacity.get(layer.parent, 1.0)
	var phase := float(layer.get("phase", 0.0))
	var frequency := float(layer.get("sway_speed", 2.1))
	var position := Vector2(float(layer.x), float(layer.y))
	position.x += sin(time * frequency + phase) * float(layer.sway) * amount
	position.y += sin(time * frequency + phase) * float(layer.get("float_y", 0)) * amount
	position.y -= absf(sin(time * (10.0 if speech else 2.0))) * float(layer.bounce) * amount
	position += pointer * float(layer.get("pointer_range", 0.0))
	var angle := deg_to_rad(float(layer.rotation) + sin(time * frequency + phase) * float(layer.get("rotation_sway", 0.0)) * amount)
	var scale := Vector2(float(layer.scale), float(layer.scale))
	if layer.get("flip_x", false):
		scale.x *= -1
	if layer.get("flip_y", false):
		scale.y *= -1
	var local := Transform2D(angle, scale, 0, position)
	var target := parent * local
	var condition := int(layer.condition)
	visible[id] = bool(layer.visible) and parent_visible and not ((condition == 1 and not speech) or (condition == 2 and speech) or (condition == 3 and not blink) or (condition == 4 and blink))
	opacity[id] = float(layer.opacity) * parent_opacity
	if layer.get("spring", false) and transforms.has(id):
		var current: Transform2D = transforms[id]
		var pos := current.origin
		var rotation := current.get_rotation()
		var velocity: Vector2 = velocities.get(id, Vector2.ZERO)
		var angular: float = angular_velocities.get(id, 0.0)
		if pos.distance_to(target.origin) > 400.0:
			pos = target.origin
			rotation = target.get_rotation()
			velocity = Vector2.ZERO
			angular = 0.0
		var remaining := step_seconds
		var w := TAU * clampf(float(layer.get("spring_frequency", 3.0)), 0.5, 12.0)
		var damping := clampf(float(layer.get("damping", 0.65)), 0.1, 2.0)
		while remaining > 0.000001:
			var dt := minf(remaining, 1.0 / 120.0)
			velocity += ((target.origin - pos) * w * w - velocity * 2.0 * damping * w) * dt
			pos += velocity * dt
			var angle_error := wrapf(target.get_rotation() - rotation, -PI, PI)
			angular += (angle_error * w * w - angular * 2.0 * damping * w) * dt
			rotation += angular * dt
			remaining -= dt
		transforms[id] = Transform2D(rotation, target.get_scale(), 0.0, pos)
		velocities[id] = velocity
		angular_velocities[id] = angular
	else:
		transforms[id] = target
		velocities[id] = Vector2.ZERO
		angular_velocities[id] = 0.0
	resolved[id] = true
	visiting.erase(id)
	return transforms[id]

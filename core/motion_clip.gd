extends RefCounted

const CHANNELS := ["x", "y", "rotation", "scale", "opacity"]

static func sample(clip: Dictionary, seconds: float) -> Dictionary:
	var keys: Array = clip.get("keys", [])
	if keys.is_empty():
		return {}
	var duration := maxf(0.01, float(clip.get("duration", 2.0)))
	var time := fposmod(seconds, duration) if clip.get("loop", true) else clampf(seconds, 0, duration)
	if time <= float(keys[0].time):
		return keys[0].duplicate()
	for i in range(1, keys.size()):
		var right: Dictionary = keys[i]
		if time < float(right.time):
			var left: Dictionary = keys[i - 1]
			var weight := inverse_lerp(float(left.time), float(right.time), time)
			match int(left.get("ease", 0)):
				1: weight = weight * weight * (3.0 - 2.0 * weight)
				2: weight = 0.0
			var result: Dictionary = {}
			for channel in CHANNELS:
				result[channel] = lerpf(float(left[channel]), float(right[channel]), weight)
			return result
	return keys.back().duplicate()

static func capture(layer: Dictionary, time: float, ease: int) -> void:
	if not layer.has("clip"):
		layer.clip = {"duration": 2.0, "loop": true, "enabled": true, "keys": []}
	var key := {"time": time, "ease": ease}
	for channel in CHANNELS:
		key[channel] = float(layer[channel])
	var keys: Array = layer.clip["keys"]
	for index in range(keys.size()):
		if absf(float(keys[index].time) - time) < 0.001:
			keys[index] = key
			return
	if keys.size() < 128:
		keys.append(key)
		keys.sort_custom(func(a, b): return float(a.time) < float(b.time))

static func layers_for_pose(layers: Array, costume: Dictionary, seconds: float, playing: bool) -> Array:
	var result: Array = []
	for source in layers:
		var layer: Dictionary = source.duplicate(false)
		if costume.has(layer.id):
			layer.visible = costume[layer.id]
		if playing and source.get("clip", {}).get("enabled", false):
			var values := sample(source.clip, seconds)
			for channel in CHANNELS:
				if values.has(channel):
					layer[channel] = values[channel]
		result.append(layer)
	return result


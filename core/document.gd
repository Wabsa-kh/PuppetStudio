extends RefCounted

const MAX_FILE_BYTES := 48 * 1024 * 1024
var data: Dictionary = {}
var textures: Dictionary = {}
var undo_stack: Array[Dictionary] = []
var redo_stack: Array[Dictionary] = []
var dirty := false

func new_layer(label: String) -> Dictionary:
	return {"id": str(Time.get_ticks_usec()) + "_" + str(randi()), "name": label, "visible": true, "tint": "ffffff", "scale_x": 1.0, "scale_y": 1.0, "talk_rule": 0, "blink_rule": 0, "rotation_min": -360.0, "rotation_max": 360.0, "rotation_drag": 0.0, "stretch": 0.0, "clip_children": false, "locked": false, "x": 0.0, "y": 0.0, "scale": 1.0, "rotation": 0.0, "pivot_x": 0.0, "pivot_y": 0.0, "flip_x": false, "flip_y": false, "opacity": 1.0, "condition": 0, "parent": "", "sway": 0.0, "float_y": 0.0, "sway_speed": 2.1, "rotation_sway": 0.0, "phase": 0.0, "bounce": 0.0, "lag": 0.12, "spring": false, "spring_frequency": 3.0, "damping": 0.65, "pointer_range": 0.0, "frames": 1, "rows": 1, "fps": 8.0, "loop": true, "image": ""}

func can_parent(child: String, parent: String) -> bool:
	var map: Dictionary = {}
	for layer in data.layers:
		map[layer.id] = layer
	var visited: Dictionary = {child: true}
	while not parent.is_empty():
		if visited.has(parent) or not map.has(parent):
			return false
		visited[parent] = true
		parent = map[parent].parent
	return true

func fresh() -> void:
	data = {"format": 1, "name": "Untitled avatar", "expressions": [], "layers": [], "assets": {}, "animations": {}, "base_x": 0.0, "base_y": 0.0, "base_scale": 1.0, "base_rotation": 0.0, "motion": 0.35, "blink": true, "threshold": -38.0, "hold": 0.12, "fps": 60}
	textures.clear()
	undo_stack.clear()
	redo_stack.clear()
	dirty = false

func checkpoint() -> void:
	undo_stack.push_back(data.duplicate(true))
	if undo_stack.size() > 40:
		undo_stack.pop_front()
	redo_stack.clear()
	dirty = true

func undo() -> bool:
	if undo_stack.is_empty():
		return false
	redo_stack.push_back(data.duplicate(true))
	data = undo_stack.pop_back()
	dirty = true
	return true

func redo() -> bool:
	if redo_stack.is_empty():
		return false
	undo_stack.push_back(data.duplicate(true))
	data = redo_stack.pop_back()
	dirty = true
	return true

func add_image(image: Image) -> String:
	var bytes := image.save_png_to_buffer()
	var hash_context := HashingContext.new()
	hash_context.start(HashingContext.HASH_SHA256)
	hash_context.update(bytes)
	var id := hash_context.finish().hex_encode()
	data.assets[id] = Marshalls.raw_to_base64(bytes)
	textures[id] = ImageTexture.create_from_image(image)
	return id

func texture(id: String) -> Texture2D:
	if data.get("animations", {}).has(id):
		return texture(data.animations[id].frames[0])
	if id.is_empty():
		return null
	if textures.has(id):
		return textures[id]
	if not data.assets.has(id):
		return null
	var image := Image.new()
	if image.load_png_from_buffer(Marshalls.base64_to_raw(data.assets[id])) != OK:
		return null
	var result := ImageTexture.create_from_image(image)
	textures[id] = result
	return result

func frame_texture(id: String, clock: float, looping := true) -> Texture2D:
	if not data.get("animations", {}).has(id):
		return texture(id)
	var clip: Dictionary = data.animations[id]
	var total := 0.0
	for duration in clip.durations:
		total += float(duration)
	var local_time := fposmod(clock, total) if looping else clampf(clock, 0, total - 0.00001)
	var loops := int(clip.get("loop_count", 0))
	if looping and loops > 0 and clock >= total * loops:
		local_time = total - 0.00001
	for index in range(clip.frames.size()):
		local_time -= float(clip.durations[index])
		if local_time < 0:
			return texture(clip.frames[index])
	return texture(clip.frames.back())

func has_art(candidate: Dictionary, id: String) -> bool:
	return candidate.assets.has(id) or candidate.get("animations", {}).has(id)

func import_image(path: String) -> String:
	if not path.get_extension().to_lower() in ["png", "webp", "jpg", "jpeg"]:
		return ""
	var source_file := FileAccess.open(path, FileAccess.READ)
	if source_file == null or source_file.get_length() > 16 * 1024 * 1024:
		return ""
	source_file.close()
	var image := Image.load_from_file(path)
	if image == null or image.is_empty() or image.get_width() > 4096 or image.get_height() > 4096:
		return ""
	return add_image(image)

func validate(candidate: Variant) -> String:
	if not candidate is Dictionary or candidate.get("format", 0) != 1:
		return "This is not a supported Puppet Studio project."
	for key in ["expressions", "layers"]:
		if not candidate.get(key) is Array:
			return "The project is missing " + key + "."
	if not candidate.get("assets") is Dictionary or not candidate.get("name") is String:
		return "Invalid project metadata."
	if candidate.has("workflow") and candidate.workflow not in ["simple", "layered", "advanced"]:
		return "Invalid character workflow."
	if not candidate.get("asset_names", {}) is Dictionary:
		return "Invalid artwork names."
	for asset_name in candidate.get("asset_names", {}).values():
		if not asset_name is String: return "Invalid artwork name."
	if not candidate.get("animations", {}) is Dictionary:
		return "Invalid animation data."
	for clip in candidate.get("animations", {}).values():
		if not clip is Dictionary or not clip.get("frames") is Array or not clip.get("durations") is Array:
			return "Invalid animation clip."
		if clip.frames.is_empty() or clip.frames.size() > 256 or clip.frames.size() != clip.durations.size():
			return "Invalid animation frame count."
		for frame_id in clip.frames:
			if not frame_id is String or not candidate.assets.has(frame_id):
				return "Animation references missing artwork."
		for duration in clip.durations:
			if not (duration is float or duration is int) or not is_finite(float(duration)) or float(duration) < 0.01 or float(duration) > 10.0:
				return "Invalid frame duration."
	if candidate.expressions.is_empty() or candidate.expressions.size() > 32 or candidate.layers.size() > 64:
		return "Use 1–32 expressions and no more than 64 layers."
	var layer_ids: Dictionary = {}
	for layer in candidate.layers:
		if not layer is Dictionary:
			return "Invalid layer."
		for key in ["id", "name", "image", "parent"]:
			if not layer.get(key) is String:
				return "Invalid layer property: " + key
		if layer_ids.has(layer.id):
			return "Duplicate layer ID."
		layer_ids[layer.id] = layer
		for key in ["x", "y", "scale", "rotation", "opacity", "condition", "sway", "bounce", "lag", "frames", "fps"]:
			if not (layer.get(key) is float or layer.get(key) is int) or not is_finite(float(layer[key])):
				return "Invalid layer number: " + key
		if layer.scale <= 0 or layer.scale > 10 or layer.frames < 1 or layer.frames > 256 or layer.fps < 0 or layer.fps > 60:
			return "Layer scale or animation settings are out of range."
		if int(layer.get("blend", 0)) not in [0, 1, 2, 3]:
			return "Invalid layer blend mode."
		if not layer.get("visible") is bool:
			return "Invalid layer visibility."
		if layer.has("tint") and (not layer.tint is String or not Color.html_is_valid(layer.tint)):
			return "Invalid layer tint."
		for key in ["pivot_x", "pivot_y", "float_y", "sway_speed", "rotation_sway", "phase", "spring_frequency", "damping", "pointer_range", "rows", "sway_speed_y", "scale_x", "scale_y", "skew", "rotation_min", "rotation_max", "rotation_drag", "stretch"]:
			if layer.has(key) and (not (layer[key] is int or layer[key] is float) or not is_finite(float(layer[key]))):
				return "Invalid layer setting: " + key
		for key in ["locked", "flip_x", "flip_y", "spring", "loop", "spring_position", "spring_rotation", "ignore_bounce", "clip_children"]:
			if layer.has(key) and not layer[key] is bool:
				return "Invalid layer option: " + key
		for rule in ["talk_rule", "blink_rule"]:
			if int(layer.get(rule, 0)) not in [0, 1, 2]:
				return "Invalid speaking / blinking rule."
		if float(layer.get("scale_x", 1)) <= 0 or float(layer.get("scale_y", 1)) <= 0 or float(layer.get("scale_x", 1)) > 10 or float(layer.get("scale_y", 1)) > 10 or float(layer.get("rotation_min", -360)) > float(layer.get("rotation_max", 360)):
			return "Invalid rig scale or rotation limits."
		if int(layer.get("rows", 1)) < 1 or int(layer.get("rows", 1)) > 64:
			return "Invalid sprite-sheet row count."
		if not layer.image.is_empty() and not has_art(candidate, layer.image):
			return "A layer references missing artwork."
	for layer in candidate.layers:
		var seen: Dictionary = {layer.id: true}
		var parent_id: String = layer.parent
		while not parent_id.is_empty():
			if seen.has(parent_id) or not layer_ids.has(parent_id):
				return "Invalid or cyclic layer attachment."
			seen[parent_id] = true
			parent_id = layer_ids[parent_id].parent
	for layer in candidate.layers:
		if not layer.get("clip_children", false): continue
		var ancestor: String = layer.parent
		while not ancestor.is_empty():
			if layer_ids[ancestor].get("clip_children", false):
				return "Nested clipping masks are not supported. Disable the ancestor mask first."
			ancestor = layer_ids[ancestor].parent
	for expression in candidate.expressions:
		if not expression is Dictionary or not expression.get("name") is String:
			return "Invalid expression."
		for slot in ["idle", "talk", "blink", "talk_blink"]:
			if not expression.get(slot) is String:
				return "Invalid expression image."
			if not expression[slot].is_empty() and not has_art(candidate, expression[slot]):
				return "An expression references missing artwork."
	for key in ["motion", "threshold", "hold", "fps"]:
		if not (candidate.get(key) is int or candidate.get(key) is float) or not is_finite(float(candidate[key])):
			return "Invalid project setting: " + key
	if not candidate.get("blink") is bool:
		return "Invalid blink setting."
	for key in ["base_x", "base_y", "base_scale", "base_rotation", "blink_min", "blink_max", "blink_duration", "idle_dim", "bounce_force", "bounce_gravity"]:
		if candidate.has(key) and (not (candidate[key] is int or candidate[key] is float) or not is_finite(float(candidate[key]))):
			return "Invalid character transform."
	var costumes: Variant = candidate.get("costumes", [])
	if not costumes is Array or costumes.size() > 32:
		return "Use no more than 32 costumes."
	for costume in costumes:
		if not costume is Dictionary or not costume.get("name") is String or not costume.get("layers") is Dictionary:
			return "Invalid costume."
		for id in costume.layers:
			if not id is String or not costume.layers[id] is bool:
				return "Invalid costume visibility."
	var hotkey_owners: Array = candidate.layers.duplicate()
	hotkey_owners.append_array(costumes)
	for owner in hotkey_owners:
		for field in ["hotkey", "hotkey_mods"]:
			if owner.has(field) and (not (owner[field] is int or owner[field] is float) or not is_finite(float(owner[field]))):
				return "Invalid keyboard shortcut."
		if int(owner.get("hotkey", 0)) < 0 or int(owner.get("hotkey", 0)) > 254 or int(owner.get("hotkey_mods", 3)) < 0 or int(owner.get("hotkey_mods", 3)) > 7:
			return "Keyboard shortcut is out of range."
	for expression in candidate.expressions:
		if expression.has("trigger_mode") and (not expression.trigger_mode is float and not expression.trigger_mode is int):
			return "Invalid expression trigger."
		if int(expression.get("trigger_mode", 0)) not in [0, 1, 2, 3]:
			return "Invalid expression trigger mode."
		var seconds: Variant = expression.get("reaction_seconds", 2.0)
		if not (seconds is float or seconds is int) or not is_finite(float(seconds)) or seconds < 0.1 or seconds > 60:
			return "Invalid reaction duration."
	for layer in candidate.layers:
		if not layer.has("clip"):
			continue
		var clip: Variant = layer.clip
		if not clip is Dictionary or not clip.get("keys") is Array or clip["keys"].size() > 128:
			return "Invalid motion clip."
		if not clip.get("enabled") is bool or not clip.get("loop") is bool:
			return "Invalid motion clip options."
		var duration: Variant = clip.get("duration")
		if not (duration is float or duration is int) or not is_finite(float(duration)) or duration < 0.1 or duration > 60:
			return "Invalid motion duration."
		var last := -1.0
		for key in clip["keys"]:
			if not key is Dictionary:
				return "Invalid motion keyframe."
			for field in ["time", "x", "y", "rotation", "scale", "opacity", "ease"]:
				if not (key.get(field) is float or key.get(field) is int) or not is_finite(float(key[field])):
					return "Invalid keyframe value."
			if key.time <= last or key.time < 0 or key.time > duration or key.scale <= 0 or key.scale > 10 or key.opacity < 0 or key.opacity > 1 or int(key.ease) not in [0, 1, 2]:
				return "Keyframes must be ordered and inside the clip duration."
			last = float(key.time)
	if int(candidate.get("output_size", 512)) not in [256, 512, 1024, 2048]:
		return "Invalid output resolution."
	if int(candidate.get("fps", 60)) not in [20, 30, 60, 120]:
		return "Invalid output frame rate."
	if candidate.has("output_background") and (not candidate.output_background is String or not Color.html_is_valid(candidate.output_background)):
		return "Invalid output background color."
	if candidate.has("pixel_art") and not candidate.pixel_art is bool:
		return "Invalid pixel-art setting."
	return ""

func save_to(path: String) -> String:
	var error := validate(data)
	if not error.is_empty(): return error
	var payload := JSON.stringify(data)
	var encoded := payload.to_utf8_buffer()
	if encoded.size() > MAX_FILE_BYTES:
		return "This alpha limits a project to 48 MB. Use smaller artwork."
	var temp_path := path + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return "Cannot write to this folder. Choose another location."
	file.store_buffer(encoded)
	file.flush()
	var write_error := file.get_error()
	file.close()
	var verification := FileAccess.open(temp_path, FileAccess.READ)
	if write_error != OK or verification == null or verification.get_length() != encoded.size():
		if verification != null: verification.close()
		return "The save could not be written completely. Your previous project was kept. Choose a folder with enough free space and try again."
	verification.close()
	if FileAccess.file_exists(path):
		var backup_error := DirAccess.copy_absolute(path, path + ".bak")
		if backup_error != OK:
			return "Could not preserve the previous save; original kept."
	var err := DirAccess.rename_absolute(temp_path, path)
	if err != OK:
		return "Could not replace the save. The temporary copy and backup were retained."
	dirty = false
	return ""

func load_from(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_FILE_BYTES:
		return "Cannot read this project, or it exceeds 48 MB."
	var parser := JSON.new()
	var parse_error := parser.parse(file.get_as_text())
	file.close()
	if parse_error != OK:
		return "This project contains invalid JSON. Your current avatar has been kept."
	var candidate: Variant = parser.data
	var error := validate(candidate)
	if not error.is_empty():
		return error
	var decoded: Dictionary = {}
	var pixels := 0
	for id in candidate.assets:
		if not candidate.assets[id] is String:
			return "Invalid embedded artwork."
		var png_bytes := Marshalls.base64_to_raw(candidate.assets[id])
		if png_bytes.size() < 24 or png_bytes.slice(0, 8) != PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10]):
			return "Invalid embedded PNG header."
		var width := (png_bytes[16] << 24) | (png_bytes[17] << 16) | (png_bytes[18] << 8) | png_bytes[19]
		var height := (png_bytes[20] << 24) | (png_bytes[21] << 16) | (png_bytes[22] << 8) | png_bytes[23]
		if width < 1 or height < 1 or width > 4096 or height > 4096:
			return "Embedded artwork exceeds the dimension limit."
		pixels += width * height
		if pixels > 48 * 1024 * 1024:
			return "The project exceeds the decoded artwork limit."
		var image := Image.new()
		if image.load_png_from_buffer(png_bytes) != OK:
			return "An embedded image could not be decoded."
		decoded[id] = ImageTexture.create_from_image(image)
	data = candidate
	if not data.has("animations"):
		data.animations = {}
	textures = decoded
	undo_stack.clear()
	redo_stack.clear()
	dirty = false
	return ""

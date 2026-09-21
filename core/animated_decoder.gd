extends RefCounted
# Original bounded container decoder. Pixel decompression uses Godot's native codecs.
# Format references: W3C PNG Third Edition; Google WebP RIFF Container Specification.

const PNG_SIGNATURE := [137, 80, 78, 71, 13, 10, 26, 10]
const MAX_PIXELS := 48 * 1024 * 1024
var crc_table: Array[int] = []

static func animated_kind(bytes: PackedByteArray) -> String:
	if bytes.size() >= 8 and bytes.slice(0, 8) == PackedByteArray(PNG_SIGNATURE):
		var cursor := 8
		while cursor + 12 <= bytes.size():
			var length := _be32(bytes, cursor)
			if length < 0 or cursor + 12 + length > bytes.size():
				return ""
			var type := bytes.slice(cursor + 4, cursor + 8).get_string_from_ascii()
			if type == "acTL":
				return "apng"
			if type == "IDAT":
				return ""
			cursor += length + 12
	if bytes.size() >= 30 and bytes.slice(0, 4).get_string_from_ascii() == "RIFF" and bytes.slice(8, 12).get_string_from_ascii() == "WEBP":
		if bytes.slice(12, 16).get_string_from_ascii() == "VP8X" and (bytes[20] & 2) != 0:
			return "webp"
	return ""

func decode(bytes: PackedByteArray) -> Dictionary:
	if bytes.size() > 16 * 1024 * 1024:
		return {"error": "Animated file exceeds 16 MB."}
	var kind := animated_kind(bytes)
	if kind == "apng":
		return _apng(bytes)
	if kind == "webp":
		return _webp(bytes)
	return {"error": "Not a supported animated container."}

static func _be32(bytes: PackedByteArray, at: int) -> int:
	return (bytes[at] << 24) | (bytes[at + 1] << 16) | (bytes[at + 2] << 8) | bytes[at + 3]

static func _le24(bytes: PackedByteArray, at: int) -> int:
	return bytes[at] | (bytes[at + 1] << 8) | (bytes[at + 2] << 16)

func _big(value: int) -> PackedByteArray:
	return PackedByteArray([(value >> 24) & 255, (value >> 16) & 255, (value >> 8) & 255, value & 255])

func _little24(value: int) -> PackedByteArray:
	return PackedByteArray([value & 255, (value >> 8) & 255, (value >> 16) & 255])

func _crc(bytes: PackedByteArray) -> int:
	if crc_table.is_empty():
		for number in range(256):
			var value := number
			for bit in range(8):
				value = (value >> 1) ^ (0xedb88320 if value & 1 else 0)
			crc_table.append(value)
	var result := 0xffffffff
	for value in bytes:
		result = crc_table[(result ^ value) & 255] ^ (result >> 8)
	return (result ^ 0xffffffff) & 0xffffffff

func _png_chunk(type: String, payload: PackedByteArray) -> PackedByteArray:
	var content := type.to_ascii_buffer() + payload
	return _big(payload.size()) + content + _big(_crc(content))

func _apng(bytes: PackedByteArray) -> Dictionary:
	var header := PackedByteArray()
	var palette_chunks := PackedByteArray()
	var controls: Array[Dictionary] = []
	var control: Dictionary = {}
	var canvas_width := 0
	var canvas_height := 0
	var declared_frames := 0
	var loop_count := 0
	var cursor := 8
	var sequence := 0
	while cursor + 12 <= bytes.size():
		var length := _be32(bytes, cursor)
		if length < 0 or cursor + 12 + length > bytes.size():
			return {"error": "Truncated PNG chunk."}
		var type := bytes.slice(cursor + 4, cursor + 8).get_string_from_ascii()
		var payload := bytes.slice(cursor + 8, cursor + 8 + length)
		match type:
			"IHDR":
				if length != 13:
					return {"error": "Invalid PNG dimensions."}
				header = payload
				canvas_width = _be32(payload, 0)
				canvas_height = _be32(payload, 4)
			"acTL":
				if length != 8:
					return {"error": "Invalid APNG header."}
				declared_frames = _be32(payload, 0)
				loop_count = _be32(payload, 4)
			"PLTE", "tRNS":
				palette_chunks += _png_chunk(type, payload)
			"fcTL":
				if length != 26 or _be32(payload, 0) != sequence:
					return {"error": "Invalid APNG frame sequence."}
				sequence += 1
				if not control.is_empty():
					controls.append(control)
				var denominator := (payload[22] << 8) | payload[23]
				control = {"width": _be32(payload, 4), "height": _be32(payload, 8), "x": _be32(payload, 12), "y": _be32(payload, 16), "duration": clampf(float((payload[20] << 8) | payload[21]) / float(100 if denominator == 0 else denominator), 0.02, 10.0), "dispose": payload[24], "blend": payload[25], "data": PackedByteArray()}
			"IDAT":
				if not control.is_empty():
					control.data += payload
			"fdAT":
				if length < 4 or control.is_empty() or _be32(payload, 0) != sequence:
					return {"error": "Invalid APNG frame data."}
				sequence += 1
				control.data += payload.slice(4)
			"IEND":
				break
		cursor += length + 12
	if not control.is_empty():
		controls.append(control)
	if canvas_width < 1 or canvas_height < 1 or canvas_width > 2048 or canvas_height > 2048 or controls.size() != declared_frames or controls.is_empty() or controls.size() > 256 or canvas_width * canvas_height * controls.size() > MAX_PIXELS:
		return {"error": "APNG exceeds its frame or decoded-size limit."}
	var canvas := Image.create(canvas_width, canvas_height, false, Image.FORMAT_RGBA8)
	canvas.fill(Color.TRANSPARENT)
	var frames: Array[Image] = []
	var durations: Array[float] = []
	for frame in controls:
		if frame.width < 1 or frame.height < 1 or frame.x + frame.width > canvas_width or frame.y + frame.height > canvas_height or frame.dispose > 2 or frame.blend > 1:
			return {"error": "Invalid APNG frame rectangle."}
		var frame_header := _big(frame.width) + _big(frame.height) + header.slice(8)
		var png := PackedByteArray(PNG_SIGNATURE) + _png_chunk("IHDR", frame_header) + palette_chunks + _png_chunk("IDAT", frame.data) + _png_chunk("IEND", PackedByteArray())
		var image := Image.new()
		if image.load_png_from_buffer(png) != OK:
			return {"error": "Could not decode APNG pixels."}
		image.convert(Image.FORMAT_RGBA8)
		var old: Image = canvas.duplicate() if frame.dispose == 2 else null
		var rect := Rect2i(0, 0, frame.width, frame.height)
		var at := Vector2i(frame.x, frame.y)
		if frame.blend == 0:
			canvas.blit_rect(image, rect, at)
		else:
			canvas.blend_rect(image, rect, at)
		frames.append(canvas.duplicate())
		durations.append(frame.duration)
		if frame.dispose == 1:
			canvas.fill_rect(Rect2i(at, rect.size), Color.TRANSPARENT)
		elif frame.dispose == 2:
			canvas = old
	return {"frames": frames, "durations": durations, "loop_count": loop_count}

func _riff_chunk(type: String, payload: PackedByteArray) -> PackedByteArray:
	var length := PackedByteArray()
	length.resize(4)
	length.encode_u32(0, payload.size())
	return type.to_ascii_buffer() + length + payload + (PackedByteArray([0]) if payload.size() % 2 else PackedByteArray())

func _webp(bytes: PackedByteArray) -> Dictionary:
	var cursor := 12
	var width := 0
	var height := 0
	var background := Color.TRANSPARENT
	var loop_count := 0
	var payloads: Array[PackedByteArray] = []
	while cursor + 8 <= bytes.size():
		var length := int(bytes.decode_u32(cursor + 4))
		if cursor + 8 + length > bytes.size():
			return {"error": "Truncated WebP chunk."}
		var type := bytes.slice(cursor, cursor + 4).get_string_from_ascii()
		var payload := bytes.slice(cursor + 8, cursor + 8 + length)
		if type == "VP8X" and length == 10:
			width = _le24(payload, 4) + 1
			height = _le24(payload, 7) + 1
		elif type == "ANIM" and length == 6:
			background = Color8(payload[2], payload[1], payload[0], payload[3])
			loop_count = payload.decode_u16(4)
		elif type == "ANMF":
			payloads.append(payload)
		cursor += length + 8 + length % 2
	if width < 1 or height < 1 or width > 2048 or height > 2048 or payloads.is_empty() or payloads.size() > 256 or width * height * payloads.size() > MAX_PIXELS:
		return {"error": "WebP exceeds its frame or decoded-size limit."}
	var canvas := Image.create(width, height, false, Image.FORMAT_RGBA8)
	canvas.fill(background)
	var frames: Array[Image] = []
	var durations: Array[float] = []
	for payload in payloads:
		if payload.size() < 24:
			return {"error": "Invalid WebP frame."}
		var x := _le24(payload, 0) * 2
		var y := _le24(payload, 3) * 2
		var w := _le24(payload, 6) + 1
		var h := _le24(payload, 9) + 1
		if x + w > width or y + h > height:
			return {"error": "WebP frame is outside the canvas."}
		var extended := PackedByteArray([16, 0, 0, 0]) + _little24(w - 1) + _little24(h - 1)
		var body := "WEBP".to_ascii_buffer() + _riff_chunk("VP8X", extended) + payload.slice(16)
		var file_size := PackedByteArray()
		file_size.resize(4)
		file_size.encode_u32(0, body.size())
		var image := Image.new()
		if image.load_webp_from_buffer("RIFF".to_ascii_buffer() + file_size + body) != OK:
			return {"error": "Could not decode WebP frame pixels."}
		image.convert(Image.FORMAT_RGBA8)
		var rect := Rect2i(0, 0, w, h)
		var at := Vector2i(x, y)
		if payload[15] & 2:
			canvas.blit_rect(image, rect, at)
		else:
			canvas.blend_rect(image, rect, at)
		frames.append(canvas.duplicate())
		durations.append(clampf(_le24(payload, 12) / 1000.0, 0.02, 10.0))
		if payload[15] & 1:
			canvas.fill_rect(Rect2i(at, rect.size), background)
	return {"frames": frames, "durations": durations, "loop_count": loop_count}

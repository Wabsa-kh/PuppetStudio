extends SceneTree

const Detector = preload("res://core/talking_detector.gd")
const Document = preload("res://core/document.gd")
const PoseSolver = preload("res://core/pose_solver.gd")
const AnimatedDecoder = preload("res://core/animated_decoder.gd")
var failures := 0
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
	else:
		print("PASS: " + message)

func _initialize() -> void:
	var detector = Detector.new()
	check(not detector.update(-20, 0.01), "Attack rejects a brief spike")
	check(detector.update(-20, 0.02), "Speech opens mouth after attack")
	check(detector.update(-41, 0.5), "Hysteresis prevents threshold chatter")
	check(detector.update(-80, 0.1), "Hold bridges short pauses")
	check(not detector.update(-80, 0.11), "Release closes mouth after silence")
	check(not detector.update(NAN, 0.1), "Non-finite samples reset safely")
	check(is_equal_approx(Detector.rms_db(PackedVector2Array()), -96), "Empty audio is finite silence")
	var opposite_phase := PackedVector2Array([Vector2(0.5, -0.5), Vector2(-0.5, 0.5)])
	check(absf(Detector.rms_db(opposite_phase) + 6.0206) < 0.01, "Opposite-phase stereo retains energy")
	var document = Document.new()
	document.fresh()
	var art := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	art.fill(Color(1, 0, 0, 0.5))
	var asset: String = document.add_image(art)
	document.data.expressions.append({"name": "Test", "idle": asset, "talk": "", "blink": "", "talk_blink": ""})
	check(document.validate(document.data).is_empty(), "Valid portable project accepted")
	document.checkpoint()
	document.data.name = "Changed"
	check(document.undo() and document.data.name == "Untitled avatar", "Undo restores project")
	check(document.redo() and document.data.name == "Changed", "Redo restores edit")
	var path := "user://core_test.puppet"
	check(document.save_to(path).is_empty(), "Project save succeeds")
	document.data.name = "Second save"
	check(document.save_to(path).is_empty(), "Existing project replacement succeeds")
	check(FileAccess.file_exists(path + ".bak"), "Previous good save retained")
	var restored = Document.new()
	check(restored.load_from(path).is_empty(), "Portable project loads")
	check(restored.data.name == "Second save" and restored.texture(asset).get_width() == 16, "Artwork and state survive round trip")
	var invalid: Dictionary = restored.data.duplicate(true)
	invalid.expressions[0].idle = "missing"
	check(not restored.validate(invalid).is_empty(), "Missing referenced asset rejected")
	invalid = restored.data.duplicate(true)
	var layer: Dictionary = restored.new_layer("Invalid")
	layer.parent = layer.id
	invalid.layers.append(layer)
	check(not restored.validate(invalid).is_empty(), "Cyclic hierarchy rejected")
	invalid = restored.data.duplicate(true)
	invalid.threshold = "not a number"
	check(not restored.validate(invalid).is_empty(), "Malformed settings rejected")
	invalid = restored.data.duplicate(true)
	invalid.fps = 47
	check(not restored.validate(invalid).is_empty(), "Unsupported output frame rate rejected")
	invalid = restored.data.duplicate(true)
	invalid.output_background = "not-a-color"
	check(not restored.validate(invalid).is_empty(), "Malformed custom capture color rejected")
	invalid = restored.data.duplicate(true)
	invalid.expressions[0].key = KEY_A
	var duplicate_expression: Dictionary = invalid.expressions[0].duplicate(true)
	duplicate_expression.name = "Duplicate key"
	invalid.expressions.append(duplicate_expression)
	check(not restored.validate(invalid).is_empty(), "Duplicate focused expression shortcuts rejected")
	invalid = restored.data.duplicate(true)
	invalid.expressions[0].key = KEY_B
	check(not restored.validate(invalid).is_empty(), "Blink key cannot also trigger an expression")
	var malformed := FileAccess.open("user://broken_test.puppet", FileAccess.WRITE)
	malformed.store_string("{broken")
	malformed.close()
	check(not restored.load_from("user://broken_test.puppet").is_empty(), "Malformed JSON rejected without replacing document")
	check(restored.data.name == "Second save", "Failed import preserves current document")
	var parent: Dictionary = document.new_layer("Parent")
	parent.x = 20.0
	parent.rotation = 90.0
	parent.scale = 2.0
	var child: Dictionary = document.new_layer("Child")
	child.tint = "80c0ffff"
	check(Color.html_is_valid(child.tint), "Per-part color tint uses portable HTML color data")
	child.parent = parent.id
	child.x = 10.0
	var solver = PoseSolver.new()
	var poses: Dictionary = solver.evaluate([child, parent], 0.016, 0, false, false, 0)
	check(poses[child.id].origin.distance_to(Vector2(20, 20)) < 0.001, "Parent rotation and scale transform child, independent of draw order")
	parent.visible = false
	solver.evaluate([child, parent], 0.016, 0, false, false, 0)
	check(not solver.visible[child.id], "Hidden parent hides child")
	parent.visible = true
	parent.opacity = 0.5
	child.opacity = 0.5
	solver.evaluate([child, parent], 0.016, 0, false, false, 0)
	check(is_equal_approx(solver.opacity[child.id], 0.25), "Opacity inherits through hierarchy")
	child.spring = true
	child.x = 60.0
	solver.evaluate([child, parent], 1.0 / 60.0, 0, false, false, 0)
	check(solver.transforms[child.id].origin.y < 120, "Spring motion follows instead of teleporting")
	for tick in range(300):
		solver.evaluate([child, parent], 1.0 / 60.0, tick / 60.0, false, false, 0)
	check(solver.transforms[child.id].origin.distance_to(Vector2(20, 120)) < 0.1, "Spring settles to target without drift")
	document.data.layers = [parent, child]
	check(not document.can_parent(parent.id, child.id), "Reparenting rejects descendant cycles")
	check(document.can_parent(child.id, parent.id), "Valid reparenting accepted")
	var second_art := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	second_art.fill(Color.GREEN)
	var second_id: String = document.add_image(second_art)
	document.data.animations.test_clip = {"frames": [asset, second_id], "durations": [0.1, 0.2]}
	check(document.frame_texture("test_clip", 0.05) == document.texture(asset), "Animated art respects first-frame timing")
	check(document.frame_texture("test_clip", 0.15) == document.texture(second_id), "Animated art advances by duration")
	check(document.frame_texture("test_clip", 0.35) == document.texture(asset), "Animated art loops")
	check(document.frame_texture("test_clip", 9.0, false) == document.texture(second_id), "One-shot animation holds final frame")
	for format in ["png", "webp"]:
		var decoder = AnimatedDecoder.new()
		var decoded: Dictionary = decoder.decode(FileAccess.get_file_as_bytes("res://tests/fixtures/two-frames." + format))
		check(not decoded.has("error"), format + " animation decodes: " + str(decoded.get("error", "OK")))
		if not decoded.has("error"):
			check(decoded.frames.size() == 2 and absf(decoded.durations[1] - 0.2) < 0.001, format + " preserves frame timing")
			check(decoded.frames[0].get_pixel(5, 5).r > 0.9 and decoded.frames[1].get_pixel(20, 20).g > 0.9, format + " preserves frame pixels")
			check(decoded.frames[1].get_pixel(5, 5).a < 0.01, format + " handles frame replacement and transparency")
	for temporary in [path, path + ".bak", "user://broken_test.puppet"]:
		DirAccess.remove_absolute(temporary)
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

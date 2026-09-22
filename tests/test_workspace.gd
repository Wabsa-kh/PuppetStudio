extends SceneTree

var failures := 0
var checks := 0
var app
var evidence_dir := ""

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
	else:
		print("PASS: " + message)

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence="):
			evidence_dir = arg.trim_prefix("--evidence=")
	call_deferred("run")

func run() -> void:
	app = load("res://main.tscn").instantiate()
	app.session_path = 'user://automated-test-recovery.puppet'
	root.add_child(app)
	await process_frame
	app.recovery_dialog.hide()
	check(app.document.data.expressions.size() == 3, "Sample starts with three expressions")
	check(app.document.validate(app.document.data).is_empty(), "Sample document validates")
	app._select_expression(1)
	check(app.avatar.expression == 1, "Expression button action changes runtime channel")
	app.talk_button.button_pressed = true
	app._toggle_test()
	await process_frame
	check(app.avatar.talking, "Test-talk control reaches renderer")
	app.avatar.force_blink()
	await process_frame
	check(app.avatar.blinking and app.avatar.talking, "Blink and speech can run together")
	var artwork := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	artwork.fill(Color(0.9, 0.7, 0.3, 0.7))
	var imported := "user://test_accessory.png"
	artwork.save_png(imported)
	app.import_as_layer = true
	app.selected_slot = "new_layer"
	app._import_selected(ProjectSettings.globalize_path(imported))
	check(app.document.data.layers.size() == 1, "Real PNG import creates accessory layer")
	app._set_layer("x", 70.0)
	app._set_layer("condition", 1)
	check(app.document.data.layers[0].x == 70.0, "Inspector command edits layer transform")
	app._undo()
	check(app.document.data.layers[0].condition == 0, "Inspector edit can be undone")
	app._redo()
	check(app.document.data.layers[0].condition == 1, "Inspector edit can be redone")
	app._duplicate_layer()
	check(app.document.data.layers.size() == 2 and app.document.data.layers[0].id != app.document.data.layers[1].id, "Duplicate layer receives independent identity")
	app._delete_layer()
	var clip_id: String = await app._import_gif(ProjectSettings.globalize_path("res://tests/fixtures/two-frames.gif"))
	check(not clip_id.is_empty(), "Animated GIF decoder completes")
	if not clip_id.is_empty():
		var clip: Dictionary = app.document.data.animations[clip_id]
		check(clip.frames.size() == 2 and absf(clip.durations[1] - 0.2) < 0.001, "GIF frame count and timing preserved")
		var frame_a: Image = app.document.texture(clip.frames[0]).get_image()
		var frame_b: Image = app.document.texture(clip.frames[1]).get_image()
		check(frame_a.get_pixel(5, 5).r > 0.9 and frame_b.get_pixel(20, 20).g > 0.9, "GIF frames contain expected artwork")
		check(frame_b.get_pixel(5, 5).a < 0.01, "GIF disposal clears previous frame pixels")
	app.name_edit.text = "Custom expression"
	app._create_expression()
	check(app.document.data.expressions.size() == 4, "New expression preserves existing mappings")
	app._global_action("expression:0", true)
	check(app.avatar.expression == 0, "Global expression command routes correctly")
	app._global_action("ptt", true)
	check(app.global_ptt, "Global hold activates")
	app._global_action("ptt", false)
	check(not app.global_ptt, "Global hold releases")
	var bridge_error: String = app.global_input.start()
	check(bridge_error.is_empty(), "Windows input helper starts")
	var heartbeat_deadline := Time.get_ticks_msec() + 35000
	while app.global_input.active and not app.global_input.received_heartbeat and Time.get_ticks_msec() < heartbeat_deadline:
		await create_timer(0.1).timeout
	print("BRIDGE_OBSERVATION: active=%s heartbeat=%s age=%.2f" % [app.global_input.active, app.global_input.received_heartbeat, app.global_input.heartbeat_age])
	check(app.global_input.active and app.global_input.received_heartbeat, "Authenticated input helper heartbeat received")
	app.global_input.stop()
	check(not app.global_input.active and not app.global_ptt, "Stopping input clears held PTT")
	app._toggle_output()
	await process_frame
	check(is_instance_valid(app.output_window) and app.output_window.visible, "Dedicated output window opens")
	check(app.output_window.transparent_bg and app.output_window.borderless, "Output requests alpha and borderless display")
	app._set_output_background(1)
	check(app.output_background.color == Color("00ff00"), "Color-key fallback applies")
	app._set_output_background(0)
	app.mic.start("Default")
	await create_timer(1.5).timeout
	print("MICROPHONE_OBSERVATION: active=%s samples_received=%s devices=%d" % [app.mic.active, app.mic.available, AudioServer.get_input_device_list().size()])
	app.mic.stop()
	check(not app.mic.detector.talking, "Stopping microphone resets detector")
	await RenderingServer.frame_post_draw
	var alpha_image: Image = app.render_target.get_texture().get_image()
	check(alpha_image.get_pixel(0, 0).a < 0.01, "Rendered output corner retains transparency")
	check(alpha_image.get_pixel(256, 256).a > 0.9, "Avatar artwork actually renders")
	if not evidence_dir.is_empty():
		alpha_image.save_png(evidence_dir.path_join("output-alpha.png"))
	app._toggle_output()
	app.selected_layer = -1
	app.test_talking = false
	app.talk_button.button_pressed = false
	app._delete_layer() # Base artwork cannot be deleted with accessory action.
	check(app.document.data.layers.size() == 1, "Delete accessory action cannot delete base")
	app.selected_layer = 0
	app._delete_layer()
	check(app.document.data.layers.is_empty(), "Accessory deletion works")
	app.document.data.expressions.pop_back()
	app._select_expression(0)
	app.avatar.blink_left = 0
	app.avatar.next_blink = 10
	app._refresh_all()
	await process_frame
	await RenderingServer.frame_post_draw
	if not evidence_dir.is_empty():
		root.get_texture().get_image().save_png(evidence_dir.path_join("workspace.png"))
		app.document.save_to(evidence_dir.path_join("Mochi.puppet"))
	app.document.dirty = false
	DirAccess.remove_absolute(imported)
	print("RESULT: %d workspace checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

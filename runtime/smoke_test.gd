extends Node

var failures := 0
var checks := 0

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + description)
	else:
		print("PASS: " + description)

func run(app: Control, screenshot: String = "") -> void:
	app.recovery_dialog.hide()
	await get_tree().process_frame
	check(app.document.validate(app.document.data).is_empty(), "Exported sample document validates")
	app._select_expression(1)
	check(app.avatar.expression == 1, "Exported expression control works")
	app.talk_button.button_pressed = true
	app._toggle_test()
	app.avatar.force_blink()
	await get_tree().process_frame
	check(app.avatar.talking and app.avatar.blinking, "Exported mouth and eyes run independently")
	var error: String = app.global_input.start()
	check(error.is_empty(), "Packaged background input helper starts")
	await get_tree().create_timer(1.5).timeout
	check(app.global_input.received_heartbeat, "Packaged input helper heartbeat arrives")
	app.global_input.stop()
	app._toggle_output()
	await get_tree().process_frame
	check(is_instance_valid(app.output_window) and app.output_window.visible, "Exported output window opens")
	app._set_output_background(2)
	check(app.output_background.color == Color("ff00ff"), "Exported key-color control works")
	app._set_output_background(0)
	await RenderingServer.frame_post_draw
	var rendered: Image = app.render_target.get_texture().get_image()
	check(rendered.get_pixel(0, 0).a < 0.01, "Exported output retains alpha")
	check(rendered.get_pixel(256, 256).a > 0.9, "Exported avatar is visible")
	app._toggle_output()
	var path := "user://export_smoke.puppet"
	check(app.document.save_to(path).is_empty(), "Exported build saves a portable project")
	check(app.document.load_from(path).is_empty(), "Exported build reloads artwork")
	DirAccess.remove_absolute(path)
	if FileAccess.file_exists(path + ".bak"):
		DirAccess.remove_absolute(path + ".bak")
	app.test_talking = false
	app.talk_button.button_pressed = false
	app.avatar.blink_left = 0
	app.avatar.next_blink = 20
	app._select_expression(0)
	app.document.dirty = false
	app.status.text = "Ready · Add your artwork or enable a microphone in the Audio tab."
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if not screenshot.is_empty():
		app.document.save_to(screenshot.get_base_dir().path_join("Mochi.puppet"))
		var image: Image = app.get_viewport().get_texture().get_image()
		check(image.save_png(screenshot) == OK, "Exported workspace screenshot saved")
	print("EXPORTED_RESULT: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)

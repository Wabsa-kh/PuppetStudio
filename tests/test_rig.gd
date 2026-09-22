extends SceneTree

const Rig = preload("res://core/rig.gd")
const Solver = preload("res://core/pose_solver.gd")
var checks := 0
var failures := 0

func check(value: bool, label: String) -> void:
	checks += 1
	if value:
		print("PASS: " + label)
	else:
		failures += 1
		printerr("FAIL: " + label)

func _initialize() -> void:
	call_deferred("run")

func exchange(peer: WebSocketPeer, message: Dictionary) -> Dictionary:
	peer.send_text(JSON.stringify(message))
	for attempt in range(100):
		peer.poll()
		if peer.get_available_packet_count() > 0:
			var result: Variant = JSON.parse_string(peer.get_packet().get_string_from_utf8())
			return result if result is Dictionary else {}
		await create_timer(0.01).timeout
	return {}

func connect_peer(port: int) -> WebSocketPeer:
	var peer := WebSocketPeer.new()
	peer.connect_to_url("ws://127.0.0.1:" + str(port))
	for attempt in range(100):
		peer.poll()
		if peer.get_ready_state() == WebSocketPeer.STATE_OPEN: break
		await create_timer(0.01).timeout
	return peer

func run() -> void:
	var app = load("res://main.tscn").instantiate()
	app.session_path = 'user://automated-test-recovery.puppet'
	root.add_child(app)
	await process_frame
	app.recovery_dialog.hide()
	check(app.import_dialog.use_native_dialog and app.save_dialog.use_native_dialog and app.load_dialog.use_native_dialog, "All file operations request native OS dialogs")
	check(DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE), "Windows display server supports native file dialogs")
	var parent: Dictionary = app.document.new_layer("Body")
	parent.x = 40.0
	parent.rotation = 35.0
	parent.scale_x = 1.5
	var child: Dictionary = app.document.new_layer("Head")
	child.x = 100.0
	child.y = 40.0
	child.rotation = -15.0
	var layers: Array = [parent, child]
	var before := Rig.rest_transform(layers, child.id)
	Rig.reparent(layers, child, parent.id)
	var after := Rig.rest_transform(layers, child.id)
	check(before.is_equal_approx(after), "Attachment preserves full rest transform including non-uniform parent")
	Rig.reparent(layers, child, "")
	check(before.is_equal_approx(Rig.rest_transform(layers, child.id)), "Detach preserves position rotation scale")
	var before_corner := Rig.local_transform(child) * Vector2(-20, -20)
	Rig.move_pivot(child, Vector2(10, 8))
	var after_corner := Rig.local_transform(child) * (Vector2(-20, -20) - Vector2(child.pivot_x, child.pivot_y))
	check(before_corner.is_equal_approx(after_corner), "Moving pivot keeps artwork stationary")
	var solver = Solver.new()
	child.talk_rule = 1
	child.blink_rule = 1
	solver.evaluate([child], 0.016, 0, true, false, 0)
	check(not solver.visible[child.id], "Talking requirement combines with blink requirement")
	solver.evaluate([child], 0.016, 0, true, true, 0)
	check(solver.visible[child.id], "Both visibility channels satisfied")
	child.rotation = 180.0
	child.rotation_min = -20.0
	child.rotation_max = 20.0
	solver.evaluate([child], 0.016, 0, false, false, 0)
	check(absf(rad_to_deg(solver.transforms[child.id].get_rotation()) - 20) < 0.01, "Rig rotation limits constrain motion")
	child = app.document.new_layer("Wave")
	child.sway = 10.0
	child.float_y = 10.0
	child.sway_speed = 0.0
	child.sway_speed_y = 1.0
	solver.evaluate([child], 0.016, PI / 2, false, false, 1)
	check(absf(solver.transforms[child.id].origin.x) < 0.01 and absf(solver.transforms[child.id].origin.y - 10) < 0.01, "Sine axes use independent speeds")
	# Real renderer clipping and blend checks, with an empty base image.
	app.document.data.expressions = [{"name": "Rig test", "idle": "", "talk": "", "blink": "", "talk_blink": ""}]
	parent = app.document.new_layer("Mask")
	child = app.document.new_layer("Clipped child")
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color.RED)
	parent.image = app.document.add_image(image)
	image.fill(Color.GREEN)
	child.image = app.document.add_image(image)
	parent.clip_children = true
	child.parent = parent.id
	child.x = 32.0
	app.document.data.layers = [parent, child]
	app.avatar.motion_enabled = false
	app.selected_layer = 1
	app._refresh_all()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var rendered: Image = app.render_target.get_texture().get_image()
	check(rendered.get_pixel(272, 256).g > 0.9, "Clipped child draws inside parent alpha")
	check(rendered.get_pixel(304, 256).a < 0.01, "Clipped child disappears outside parent alpha")
	parent.clip_children = false
	child.blend = 1
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	rendered = app.render_target.get_texture().get_image()
	check(rendered.get_pixel(272, 256).r > 0.9 and rendered.get_pixel(272, 256).g > 0.9, "Add blend combines actual layer colors")
	child.blend = 3
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	rendered = app.render_target.get_texture().get_image()
	check(rendered.get_pixel(272, 256).r < 0.1 and rendered.get_pixel(272, 256).g < 0.1, "Multiply blend darkens actual layer colors")
	check(app._pick_layer(Vector2(288, 256)) == 1, "Canvas hit testing selects top layer")
	app._capture_costume()
	app.document.data.costumes[0].hotkey = 77
	check(app._shortcut_configuration().has("error"), "Duplicate background shortcut detected")
	app.document.data.costumes[0].hotkey = 0
	child.hotkey = 75
	check(not app._shortcut_configuration().has("error"), "Disabled costume binding does not reserve key")
	app._global_action("layer:" + child.id, true)
	await process_frame
	await process_frame
	check(not app.avatar.solver.visible[child.id], "Individual sprite shortcut toggles live visibility")
	app._cycle_costume(0)
	check(app.avatar.layer_toggles.is_empty(), "Costume switch clears live sprite toggles")
	parent.clip_children = true
	child.clip_children = true
	check(not app.document.validate(app.document.data).is_empty(), "Unsupported nested mask rejected before save")
	child.clip_children = false
	var shortcut_error: String = app._start_shortcuts()
	check(shortcut_error.is_empty(), "Custom shortcut configuration starts Windows helper")
	for attempt in range(350):
		if app.global_input.received_heartbeat or not app.global_input.active: break
		await create_timer(0.1).timeout
	check(app.global_input.active and app.global_input.received_heartbeat, "Custom shortcut helper configuration remains healthy")
	app.global_input.stop()
	# Use an available non-default test port; production server is opt-in.
	var error := ""
	for port in range(19550, 19570):
		error = app.control_server.start(port)
		if error.is_empty(): break
	check(error.is_empty(), "Local integration listener starts")
	var bad := await connect_peer(app.control_server.port)
	bad.send_text('{"token":"wrong"}')
	for attempt in range(30):
		bad.poll()
		await create_timer(0.01).timeout
	check(bad.get_ready_state() != WebSocketPeer.STATE_OPEN, "Unauthenticated integration client rejected")
	var peer := await connect_peer(app.control_server.port)
	var response := await exchange(peer, {"token": app.control_server.token})
	check(response.get("ok", false), "Integration client authenticates over real WebSocket")
	response = await exchange(peer, {"action": "mute", "enabled": true})
	check(response.get("ok", false) and app.avatar_muted, "Remote command reaches avatar controls")
	response = await exchange(peer, {"action": "expression", "index": 31})
	check(not response.get("ok", true), "Missing remote expression rejected")
	response = await exchange(peer, {"action": "mute", "enabled": "yes"})
	check(not response.get("ok", true), "Malformed remote command rejected")
	response = await exchange(peer, {"action": "reset"})
	check(response.get("ok", false) and not app.avatar_muted and app.avatar.costume == -1, "Remote reset restores performance defaults")
	peer.close()
	app.control_server.stop()
	check(not app.control_server.active and app.control_server.token.is_empty(), "Stopping integration revokes session token")
	print("RIG_RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)



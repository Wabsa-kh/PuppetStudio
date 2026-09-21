extends SceneTree

const PerformanceState = preload("res://core/performance_state.gd")
const Motion = preload("res://core/motion_clip.gd")
const Document = preload("res://core/document.gd")
var checks := 0
var failures := 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + label)
	else:
		print("PASS: " + label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var state = PerformanceState.new()
	state.activate(1, 0, true)
	state.activate(2, 1, true, 2, "keyboard")
	state.activate(3, 1, true, 2, "global")
	check(state.update(0, 4) == 3, "Most recent held expression wins")
	state.activate(2, 1, false, 2, "keyboard")
	check(state.update(0, 4) == 3, "Out-of-order release preserves other held expression")
	state.release_source("global")
	check(state.update(0, 4) == 1, "Lost helper connection restores latched expression")
	state.activate(2, 3, true, 0.4)
	check(state.update(0.2, 4) == 2, "Timed reaction overlays latched expression")
	check(state.update(0.3, 4) == 1, "Timed reaction expires without changing base")
	state.activate(2, 2, true)
	check(state.update(0, 4) == 2, "Toggle activates expression")
	state.activate(2, 2, true)
	check(state.update(0, 4) == 0, "Second toggle restores neutral")
	state.activate(1, 1, true, 2, "keyboard")
	state.release_source("keyboard")
	check(state.update(0, 4) == 0, "Focus loss cannot leave expression stuck")
	var document = Document.new()
	document.fresh()
	var layer: Dictionary = document.new_layer("Animated star")
	Motion.capture(layer, 1.0, 0)
	layer.x = 100.0
	Motion.capture(layer, 2.0, 0)
	layer.x = -100.0
	Motion.capture(layer, 0.0, 1)
	check(layer.clip["keys"][0].time == 0, "Recording inserts keys in time order")
	check(is_equal_approx(Motion.sample(layer.clip, 0.5).x, -50), "Smooth clip interpolates position")
	check(is_equal_approx(Motion.sample(layer.clip, 1.5).x, 50), "Linear clip interpolates position")
	check(is_equal_approx(Motion.sample(layer.clip, 2.5).x, -50), "Looping clip wraps time")
	layer.clip.loop = false
	check(is_equal_approx(Motion.sample(layer.clip, 9).x, 100), "One-shot clip holds final key")
	layer.clip["keys"][0].ease = 2
	check(is_equal_approx(Motion.sample(layer.clip, 0.8).x, -100), "Stepped clip holds previous key")
	layer.x = 20.0
	Motion.capture(layer, 1.0, 0)
	check(layer.clip["keys"].size() == 3 and layer.clip["keys"][1].x == 20, "Record at existing time replaces key")
	var pose := Motion.layers_for_pose([layer], {layer.id: false}, 1.0, true)
	check(not pose[0].visible and layer.visible, "Costume does not mutate default visibility")
	check(pose[0].x == 20 and layer.x == 20, "Clip samples copied layer data")
	layer.x = 77.0
	pose = Motion.layers_for_pose([layer], {}, 1.0, true)
	check(pose[0].x == 20 and layer.x == 77, "Playback preserves editable transforms")
	pose = Motion.layers_for_pose([layer], {}, 1.0, false)
	check(pose[0].x == 77, "Stopping clips restores editable pose")
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.recovery_dialog.hide()
	var art := Image.new()
	art.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="80" height="80"><path d="M40 3 L50 27 L77 29 L57 47 L63 74 L40 60 L17 74 L23 47 L3 29 L30 27Z" fill="#e0b55e" stroke="#382f2a" stroke-width="4"/></svg>')
	layer.image = scene.document.add_image(art)
	layer.x = 150.0
	layer.y = -120.0
	layer.clip["keys"].clear()
	Motion.capture(layer, 0.0, 1)
	layer.y = -155.0
	layer.rotation = 20.0
	Motion.capture(layer, 1.0, 1)
	layer.y = -120.0
	layer.rotation = 0.0
	Motion.capture(layer, 2.0, 1)
	layer.clip.loop = true
	scene.document.data.layers.append(layer)
	scene.selected_layer = 0
	scene._refresh_all()
	scene._capture_costume()
	check(scene.document.data.costumes.size() == 1, "Costume created through workspace")
	scene.document.data.costumes[0].layers[layer.id] = false
	await process_frame
	await process_frame
	check(not scene.avatar.solver.visible[layer.id], "Costume visibility reaches actual renderer")
	scene._select_expression(2)
	check(scene.avatar.costume == 0, "Expression switching preserves costume channel")
	scene._cycle_costume(0)
	await process_frame
	await process_frame
	check(scene.avatar.solver.visible[layer.id], "Costume hotkey toggles back to default")
	scene.document.data.expressions[1].trigger_mode = 1
	scene._global_action("expression:1", true)
	await process_frame
	check(scene.avatar.expression == 1, "Global held trigger reaches avatar")
	scene._global_action("release_all", false)
	await process_frame
	check(scene.avatar.expression == 2, "Global disconnect clears held trigger")
	scene.avatar.clips_preview = true
	scene.avatar.clip_time = 1.0
	scene.avatar.motion_enabled = false
	await process_frame
	await process_frame
	check(absf(scene.avatar.poses[layer.id].origin.y + 155) < 0.01, "Clip playhead reaches renderer transform")
	scene.document.data.output_size = 1024
	scene.document.data.pixel_art = true
	scene._apply_render_settings()
	await RenderingServer.frame_post_draw
	var image: Image = scene.render_target.get_texture().get_image()
	check(image.get_width() == 1024, "Capture target renders at chosen resolution")
	check(image.get_pixel(512, 512).a > 0.9 and image.get_pixel(0, 0).a < 0.01, "High-resolution output preserves scale and alpha")
	check(scene.avatar.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "Pixel-art filtering applied")
	check(scene.document.validate(scene.document.data).is_empty(), "Advanced project validates")
	var path := "user://advanced_roundtrip.puppet"
	check(scene.document.save_to(path).is_empty(), "Advanced project saves")
	var restored = Document.new()
	check(restored.load_from(path).is_empty() and restored.data.layers[0].clip["keys"].size() == 3 and restored.data.costumes.size() == 1, "Costumes and motion survive portable round trip")
	var bad: Dictionary = scene.document.data.duplicate(true)
	bad.layers[0].clip["keys"][1].time = -1
	check(not scene.document.validate(bad).is_empty(), "Unordered keyframes rejected")
	bad = scene.document.data.duplicate(true)
	bad.layers[0].clip["keys"][0].scale = 0
	check(not scene.document.validate(bad).is_empty(), "Zero-scale keyframe rejected")
	bad = scene.document.data.duplicate(true)
	bad.costumes[0].layers[layer.id] = "false"
	check(not scene.document.validate(bad).is_empty(), "Malformed costume visibility rejected")
	scene.inspector_tab = 3
	scene.inspector_tabs.current_tab = 3
	scene._refresh_inspector()
	check(scene.inspector.get_child_count() > 30, "Advanced inspector builds expression costume and clip controls")
	scene._select_expression(0)
	scene.document.data.output_size = 512
	scene.document.data.pixel_art = false
	scene._apply_render_settings()
	scene.avatar.clip_time = 0
	scene.avatar.costume = -1
	scene.document.data.costumes[0].name = "Without star"
	scene.document.dirty = false
	scene.status.text = "Motion clips · Record a pose, move the playhead, record another pose, then Play clips."
	await process_frame
	await RenderingServer.frame_post_draw
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence="):
			var folder := arg.trim_prefix("--evidence=")
			scene.get_viewport().get_texture().get_image().save_png(folder.path_join("advanced-workspace.png"))
			scene.document.save_to(folder.path_join("Advanced-Mochi.puppet"))
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(path + ".bak")
	print("ADVANCED_RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


extends SceneTree

var app
var checks := 0
var failures := 0

func check(value: bool, text: String) -> void:
	checks += 1
	if value: print("PASS: " + text)
	else:
		failures += 1
		printerr("FAIL: " + text)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	app = load("res://main.tscn").instantiate()
	app.session_path = "user://lifecycle-test-recovery.puppet"
	root.add_child(app)
	await process_frame
	app.recovery_dialog.hide()
	app._load_project("res://samples/Rigged-Mochi.puppet")
	await process_frame
	await process_frame
	var baseline := get_node_count()
	var peak := baseline
	var valid := true
	var stable := true
	var previews := true
	var path := "user://lifecycle-test-project.puppet"
	var began := Time.get_ticks_msec()
	for cycle in range(24):
		app._select_layer(cycle % 9)
		app.shell.select_page(["Image", "Layout", "Rig", "Motion", "Visibility", "Animation"][cycle % 6])
		app.shell.open_tool(["Audio", "Output", "Costumes", "Motion clips", "Integrations"][cycle % 5])
		await create_timer(1.25).timeout
		app.shell.close_tool()
		app.shell.open_assets()
		app.shell.select_asset(0)
		previews = previews and app.shell.asset_preview.texture != null
		await create_timer(1.25).timeout
		app.shell.asset_window.hide()
		app.shell.asset_window.queue_free()
		await process_frame
		if cycle % 6 == 0:
			app._toggle_output()
			await process_frame
			app._toggle_output()
		app.document.checkpoint()
		app.document.data.layers[cycle % 9].x += 5
		app._undo()
		app._redo()
		app._save_to(path)
		app._load_project(path)
		valid = valid and app.document.validate(app.document.data).is_empty() and app.document.data.layers.size() == 9
		await process_frame
		await process_frame
		peak = maxi(peak, get_node_count())
		stable = stable and get_node_count() <= baseline + 20
		if cycle % 6 == 5: print("LIFECYCLE_PROGRESS: %d / 24 cycles" % (cycle + 1))
	check(valid, "24 edit/undo/redo/save/reopen cycles preserve a valid nine-part rig")
	check(previews, "Artwork previews survive repeated browser creation and teardown")
	check(stable, "Closed windows and rebuilt inspectors do not accumulate nodes")
	check(not is_instance_valid(app.shell.tool_window) and not is_instance_valid(app.shell.asset_window), "No tool or asset windows remain after closing")
	check(not is_instance_valid(app.output_window) or not app.output_window.visible, "Repeated capture-window toggles finish closed")
	print("LIFECYCLE_OBSERVATION: %.1f seconds, baseline %d nodes, peak %d nodes" % [(Time.get_ticks_msec() - began) / 1000.0, baseline, peak])
	app._clear_recovery()
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	app.document.dirty = false
	print("LIFECYCLE_RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

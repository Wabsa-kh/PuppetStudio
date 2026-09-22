extends SceneTree

var app
var checks := 0
var failures := 0
var folder := ""

func check(value: bool, text: String) -> void:
	checks += 1
	if value: print("PASS: " + text)
	else:
		failures += 1
		printerr("FAIL: " + text)

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence="): folder = arg.trim_prefix("--evidence=")
	call_deferred("run")

func find_button(node: Node, text: String) -> Button:
	if node is Button and node.text == text: return node
	for child in node.get_children():
		var result := find_button(child, text)
		if result != null: return result
	return null

func shot(viewport: Viewport, filename: String) -> void:
	await RenderingServer.frame_post_draw
	if not folder.is_empty(): viewport.get_texture().get_image().save_png(folder.path_join(filename))

func run() -> void:
	app = load("res://main.tscn").instantiate()
	app.session_path = 'user://automated-test-recovery.puppet'
	root.add_child(app)
	await process_frame
	app.recovery_dialog.hide()
	check(app.shell.menus.size() == 8, "Eight conventional menus expose app workflows")
	check(app.shell.menus.File.size() >= 9 and app.shell.menus.Edit.size() >= 5, "File and Edit include standard actions and preferences")
	check(app.shell.slot_buttons.size() == 4, "Simple editor has four visual artwork slots")
	check(app.shell.slot_buttons.idle.icon == app.document.texture(app.document.data.expressions[0].idle), "Idle tile displays the actual assigned image")
	app._select_expression(1)
	check(app.shell.slot_buttons.talk.icon == app.document.texture(app.document.data.expressions[1].talk), "Changing expression refreshes image previews")
	check(not app.shell.parts_panel.visible, "Simple workflow hides empty rig hierarchy")
	await shot(root, "ui-simple.png")
	app.shell.open_assets()
	await process_frame
	check(app.shell.project_assets.item_count == app.document.data.assets.size(), "Asset browser enumerates project images")
	app.shell.asset_search.text = "Happy"
	app.shell.asset_search.text_changed.emit("Happy")
	check(app.shell.project_assets.item_count == 4, "Asset search filters by expression names")
	app.shell.select_asset(0)
	check(app.shell.asset_preview.texture != null, "Asset selection produces a large preview")
	var chosen: String = app.shell.selected_asset
	app.shell.asset_target.select(2)
	app.shell.assign_asset()
	check(app.document.data.expressions[1].blink == chosen, "Library assignment updates the chosen expression slot")
	app._undo()
	check(app.document.data.expressions[1].blink != chosen, "Library assignment participates in undo")
	await shot(app.shell.asset_window, "ui-assets.png")
	app.shell.asset_window.queue_free()
	await process_frame
	app.shell.open_wizard()
	await process_frame
	check(app.shell.wizard_choices.size() == 3, "Creation window offers three distinct workflows")
	await shot(app.shell.wizard, "ui-creation.png")
	app.shell.wizard.hide()
	app.shell.wizard.queue_free()
	await process_frame
	for mode in range(3):
		app.shell.create_character(mode, "Workflow test")
		check(app.document.data.workflow == ["simple", "layered", "advanced"][mode], "Creation applies workflow " + str(mode))
		check(app.document.validate(app.document.data).is_empty(), "Created workflow produces valid portable data " + str(mode))
	app._load_project("res://samples/Rigged-Mochi.puppet")
	app._select_layer(2)
	app.shell.select_page("Rig")
	check(app.shell.parts_panel.visible, "Layered project exposes parts hierarchy")
	var visible := 0
	for node in app.inspector.get_children():
		if node.visible:
			visible += 1
			check(node.get_meta("ui_category", "") == "Rig", "Rig page contains only rig controls")
	check(visible > 4 and visible < 18, "Rig page is bounded instead of a single giant inspector")
	check("Motion" in app.shell.routed_controls.values() and "Animation" in app.shell.routed_controls.values() and "Visibility" in app.shell.routed_controls.values(), "Layer features retain routes outside the current page")
	await shot(root, "ui-rig.png")
	app.shell.select_page("Motion")
	check(app.inspector.get_child(0).get_script().resource_path.ends_with("motion_visual.gd"), "Procedural motion has a live visualizer")
	for title in ["Audio", "Output", "Integrations", "Costumes", "Motion clips"]:
		app.shell.open_tool(title)
		await process_frame
		check(app.shell.tool_window.visible and app.shell.scope == title, title + " opens in a dedicated window")
		if title == "Audio":
			app._message("Dialog layering verification")
			check(app.notice.visible and app.notice.get_parent() == app.shell.tool_window, "Messages are parented above the active tool window")
			app.notice.hide()
			app.calibration_dialog.popup_centered()
			check(app.calibration_dialog.visible, "Calibration can open above Audio")
			app.calibration_dialog.hide()
		for node in app.inspector.get_children():
			if node.visible and node.has_meta("ui_category"):
				check(node.get_meta("ui_category") == title, title + " excludes unrelated controls")
		if title in ["Audio", "Motion clips"]: await shot(app.shell.tool_window, "ui-" + title.to_lower().replace(" ", "-") + ".png")
		app.shell.close_tool()
		await process_frame
		check(app.inspector == app.shell.main_inspector, title + " closes back to the contextual inspector")
	# Check preferences through their actual Apply action; restore machine settings afterward.
	var config_path := "user://workspace.cfg"
	var existed := FileAccess.file_exists(config_path)
	var original := FileAccess.get_file_as_bytes(config_path) if existed else PackedByteArray()
	app.shell.open_preferences()
	await process_frame
	check(app.shell.preferences.visible, "Appearance preferences have a dedicated window")
	find_button(app.shell.preferences, "Apply preferences").pressed.emit()
	check(FileAccess.file_exists(config_path), "Editor appearance is persisted")
	await shot(app.shell.preferences, "ui-preferences.png")
	app.shell.preferences.queue_free()
	await process_frame
	if existed:
		var file := FileAccess.open(config_path, FileAccess.WRITE)
		file.store_buffer(original)
		file.close()
	else: DirAccess.remove_absolute(config_path)
	app._build_theme()
	app.document.checkpoint()
	app._quit_app()
	var quit_dialog := app.get_node_or_null("QuitConfirmation") as ConfirmationDialog
	check(quit_dialog != null and quit_dialog.visible, "Closing unsaved work offers Save, Discard and Keep editing")
	quit_dialog.hide()
	quit_dialog.canceled.emit()
	await process_frame
	check(app.document.dirty and not app.pending_quit, "Keeping the editor open preserves unsaved work")
	app.pending_quit = true
	app._save_to("user://nonexistent-save-test-folder/avatar.puppet")
	check(not app.pending_quit and app.document.dirty, "Failed save cancels pending quit")
	app.notice.hide()
	app.document.save_to(app.session_path)
	app.document.dirty = true
	app._save_to("user://ui-safety-project.puppet")
	check(not FileAccess.file_exists(app.session_path) and not app.document.dirty, "Successful save removes stale recovery snapshots")
	app.document.save_to(app.session_path)
	app._load_project(app.session_path)
	check(app.document.dirty, "Recovered session is marked unsaved until explicitly saved")
	app._clear_recovery()
	DirAccess.remove_absolute("user://ui-safety-project.puppet")
	DirAccess.remove_absolute("user://ui-safety-project.puppet.bak")
	app.document.dirty = false
	print("UI_RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

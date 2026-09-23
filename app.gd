extends Control

const EditorShell = preload("res://ui/editor_shell.gd")
var shell
var appearance_scheme := 0
var appearance_accent := "a8bf91"

const Document = preload("res://core/document.gd")
const Microphone = preload("res://core/microphone.gd")
const Avatar = preload("res://runtime/avatar.gd")
const Checker = preload("res://ui/checker.gd")
const GlobalInput = preload("res://platform/global_input.gd")
const AnimatedDecoder = preload("res://core/animated_decoder.gd")
const PerformanceState = preload("res://core/performance_state.gd")
const MotionClip = preload("res://core/motion_clip.gd")
var performance = PerformanceState.new()
var key_time := 0.0
var key_ease := 0
const ControlServer = preload("res://platform/control_server.gd")
var control_server
var control_port := 19532
var resolution_label: Label
const Rig = preload("res://core/rig.gd")
const RigOverlay = preload("res://ui/rig_overlay.gd")
var rig_visible := true
var canvas_tool := 0
var last_import_directory := ""
var rig_overlay
var global_input
var global_ptt := false
var dragging_art := false
var output_topmost := false
var output_background_index := 0
var output_custom_color := Color("1b1e24")
var inspector_tab := 0
var inspector_tabs: TabBar
var importing := false
var document = Document.new()
var mic
var avatar
var render_target: SubViewport
var output_window: Window
var output_background: ColorRect
var layers_list: ItemList
var expression_bar: HBoxContainer
var inspector: VBoxContainer
var device_picker: OptionButton
var meter: ProgressBar
var db_label: Label
var mic_status: Label
var status: Label
var title_label: Label
var selected_layer := -1
var selected_expression := 0
var updating := false
var test_talking := false
var avatar_muted := false
var ptt_enabled := false
var output_button: Button
var talk_button: Button
var selected_slot := "idle"
var import_as_layer := false
var export_art_dialog: FileDialog
var import_dialog: FileDialog
var save_dialog: FileDialog
var load_dialog: FileDialog
var notice: AcceptDialog
var name_dialog: ConfirmationDialog
var name_edit: LineEdit
var current_path := ""
var zoom := 1.0
var preview_texture: TextureRect
var preview_area: Control
var calibration_stage := 0
var calibration_time := 0.0
var calibration_levels: Array[float] = []
var noise_floor := -60.0
var proposed_threshold := -38.0
var calibration_dialog: ConfirmationDialog
var snapshot_time := 0.0
var last_dirty := false
var autosave_pending := false
var recovery_dialog: ConfirmationDialog
var session_path := "user://recovery.puppet"
var pending_quit := false
var shot_path := ""
var view_tabs: OptionButton
var left_panel: Control
var right_panel: Control

func _ready() -> void:
	if OS.get_cmdline_user_args().has("--self-test"):
		session_path = "user://automated-test-recovery.puppet"
	Engine.max_fps = 60
	get_window().min_size = Vector2i(1080, 680)
	get_tree().auto_accept_quit = false
	_build_theme()
	document.fresh()
	_make_sample()
	mic = Microphone.new()
	add_child(mic)
	mic.devices_changed.connect(_refresh_devices)
	control_server = ControlServer.new()
	add_child(control_server)
	control_server.command_received.connect(_remote_command)
	control_server.command_validator = _validate_remote_command
	global_input = GlobalInput.new()
	add_child(global_input)
	global_input.action_received.connect(_global_action)
	render_target = SubViewport.new()
	render_target.size = Vector2i(512, 512)
	render_target.transparent_bg = true
	render_target.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(render_target)
	avatar = Avatar.new()
	avatar.document = document
	render_target.add_child(avatar)
	_build_ui()
	_build_dialogs()
	_refresh_all()
	get_window().files_dropped.connect(_files_dropped)
	var self_test := false
	for argument in OS.get_cmdline_user_args():
		if argument == "--self-test":
			self_test = true
		if argument.begins_with("--preview-shot="):
			shot_path = argument.trim_prefix("--preview-shot=")
		if argument == "--smoke-output":
			call_deferred("_toggle_output")
	if self_test:
		var smoke = preload("res://runtime/smoke_test.gd").new()
		add_child(smoke)
		smoke.call_deferred("run", self, shot_path)
	elif not shot_path.is_empty():
		get_tree().create_timer(1.5).timeout.connect(_capture_preview)
	elif FileAccess.file_exists(session_path):
		recovery_dialog.popup_centered(Vector2i(440, 170))

func _build_theme() -> void:
	var preferences := ConfigFile.new()
	preferences.load("user://workspace.cfg")
	appearance_scheme = int(preferences.get_value("appearance", "scheme", 0))
	appearance_accent = str(preferences.get_value("appearance", "accent", "a8bf91"))
	var skin := Theme.new()
	skin.default_font_size = int(preferences.get_value("appearance", "font_size", 14))
	skin.set_color("font_color", "Label", Color("d5d8de"))
	skin.set_color("font_color", "Button", Color("e0e2e7"))
	skin.set_color("font_hover_color", "Button", Color.WHITE)
	skin.set_color("font_disabled_color", "Button", Color("646970"))
	for kind in ["Button", "OptionButton", "MenuButton"]:
		skin.set_stylebox("normal", kind, _box("30343b", "454b54"))
		skin.set_stylebox("hover", kind, _box("3e454e", "68727e"))
		skin.set_stylebox("pressed", kind, _box("515447", "b6c68e"))
		skin.set_stylebox("focus", kind, _box("30343b", "b6c68e", 2))
	skin.set_stylebox("panel", "PanelContainer", _box("25282e", "363b43"))
	skin.set_stylebox("panel", "PopupMenu", _box("282c33", "555b66"))
	skin.set_stylebox("normal", "LineEdit", _box("1e2127", "414751"))
	skin.set_stylebox("focus", "LineEdit", _box("252930", "b6c68e"))
	for state in ["normal", "pressed", "hover", "hover_pressed"]:
		skin.set_stylebox(state, "CheckBox", _box("25282e", "25282e", 0))
	skin.set_stylebox("panel", "ItemList", _box("22252b", "343943"))
	skin.set_stylebox("selected", "ItemList", _box("41483d", "7d8a69"))
	skin.set_color("font_color", "ItemList", Color("d5d8de"))
	skin.set_stylebox("background", "ProgressBar", _box("171b20", "363e47"))
	skin.set_stylebox("fill", "ProgressBar", _box("99b779", "99b779"))
	skin.set_constant("separation", "VBoxContainer", 9)
	skin.set_constant("separation", "HBoxContainer", 7)
	theme = skin

func _box(fill: String, border: String, width: int = 1) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	var palette := {"25282e": "181c22", "22252b": "12161b", "30343b": "242c36", "1c1f24": "10141a"}
	box.bg_color = Color(palette.get(fill, fill) if appearance_scheme == 1 else fill)
	box.border_color = Color(appearance_accent if border in ["b6c68e", "7d8a69", "8f9e76"] else border)
	box.set_border_width_all(width)
	box.set_corner_radius_all(3)
	box.content_margin_left = 9
	box.content_margin_right = 9
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	return box

func _label(text: String, size_px: int = 14, color: String = "d5d8de") -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", Color(color))
	return label

func _button(text: String, callback: Callable, tip: String = "") -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tip
	button.custom_minimum_size.y = 30
	button.pressed.connect(callback)
	return button

func _section(parent: VBoxContainer, text: String) -> void:
	parent.add_child(HSeparator.new())
	parent.add_child(_label(text, 12, "aeb6c0"))

func _spacer(parent: Container) -> void:
	var space := Control.new()
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(space)

func _panel(width: float = 0) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = width
	return panel

func _build_ui() -> void:
	shell = EditorShell.new()
	add_child(shell)
	shell.setup(self)

func _build_dialogs() -> void:
	export_art_dialog = FileDialog.new()
	export_art_dialog.use_native_dialog = true
	export_art_dialog.access = FileDialog.ACCESS_FILESYSTEM
	export_art_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	export_art_dialog.title = "Choose an artwork export folder"
	export_art_dialog.dir_selected.connect(_export_artwork)
	add_child(export_art_dialog)
	import_dialog = FileDialog.new()
	import_dialog.use_native_dialog = true
	import_dialog.title = "Import artwork"
	import_dialog.access = FileDialog.ACCESS_FILESYSTEM
	import_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	import_dialog.filters = PackedStringArray(["*.png,*.apng,*.webp,*.jpg,*.jpeg,*.gif ; Static and animated artwork"])
	import_dialog.file_selected.connect(_import_selected)
	import_dialog.files_selected.connect(_import_many)
	add_child(import_dialog)
	save_dialog = FileDialog.new()
	save_dialog.use_native_dialog = true
	save_dialog.title = "Save portable avatar"
	save_dialog.access = FileDialog.ACCESS_FILESYSTEM
	save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	save_dialog.filters = PackedStringArray(["*.puppet ; Puppet Studio avatar"])
	save_dialog.file_selected.connect(_save_to)
	save_dialog.canceled.connect(func(): pending_quit = false)
	add_child(save_dialog)
	load_dialog = FileDialog.new()
	load_dialog.use_native_dialog = true
	load_dialog.title = "Open avatar"
	load_dialog.access = FileDialog.ACCESS_FILESYSTEM
	load_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	load_dialog.filters = PackedStringArray(["*.puppet ; Puppet Studio avatar"])
	load_dialog.file_selected.connect(_request_load)
	add_child(load_dialog)
	var settings := ConfigFile.new()
	settings.load("user://workspace.cfg")
	last_import_directory = settings.get_value("folders", "artwork", OS.get_system_dir(OS.SYSTEM_DIR_PICTURES))
	if DirAccess.dir_exists_absolute(last_import_directory):
		import_dialog.current_dir = last_import_directory
	var projects: String = settings.get_value("folders", "projects", OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS))
	if DirAccess.dir_exists_absolute(projects):
		load_dialog.current_dir = projects
		save_dialog.current_dir = projects
	notice = AcceptDialog.new()
	notice.title = "Puppet Studio"
	add_child(notice)
	name_dialog = ConfirmationDialog.new()
	name_dialog.title = "Duplicate expression"
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "Expression name"
	name_edit.custom_minimum_size = Vector2(290, 36)
	name_dialog.add_child(name_edit)
	name_dialog.confirmed.connect(_create_expression)
	add_child(name_dialog)
	calibration_dialog = ConfirmationDialog.new()
	calibration_dialog.title = "Microphone calibration"
	calibration_dialog.ok_button_text = "Use this threshold"
	calibration_dialog.confirmed.connect(func():
		document.checkpoint()
		document.data.threshold = proposed_threshold
		_refresh_inspector()
	)
	add_child(calibration_dialog)
	recovery_dialog = ConfirmationDialog.new()
	recovery_dialog.title = "Recover your last session?"
	recovery_dialog.dialog_text = "A local autosave is available. Restore it to continue editing.\nYour manually saved project has not been changed."
	recovery_dialog.ok_button_text = "Restore"
	recovery_dialog.cancel_button_text = "Use sample"
	recovery_dialog.confirmed.connect(func(): _load_project(session_path))
	add_child(recovery_dialog)

func _refresh_all() -> void:
	if global_input.active: _restart_shortcuts()
	selected_expression = clampi(selected_expression, 0, document.data.expressions.size() - 1)
	avatar.expression = performance.update(0, document.data.expressions.size())
	_apply_render_settings()
	selected_layer = mini(selected_layer, document.data.layers.size() - 1)
	layers_list.clear()
	layers_list.add_item("◈  Base character")
	for layer in document.data.layers:
		layers_list.add_item(("●  " if layer.visible else "○  ") + str(layer.name))
	layers_list.select(selected_layer + 1)
	for child in expression_bar.get_children():
		expression_bar.remove_child(child)
		child.queue_free()
	for index in range(document.data.expressions.size()):
		var state: Dictionary = document.data.expressions[index]
		var button := _button(str(index + 1) + "  " + state.name, _select_expression.bind(index))
		button.toggle_mode = true
		button.button_pressed = index == selected_expression
		expression_bar.add_child(button)
	expression_bar.add_child(_button("+", _new_expression, "Duplicate the selected expression"))
	_refresh_inspector()
	_resize_preview()
	if shell != null: shell.refresh()

func _refresh_inspector() -> void:
	updating = true
	for child in inspector.get_children():
		inspector.remove_child(child)
		child.queue_free()
	if selected_layer >= 0:
		_build_layer_inspector()
	else:
		inspector.add_child(_label("Expression", 12, "aeb6c0"))
		inspector.add_child(_label(str(document.data.expressions[selected_expression].name), 18))
		var expression_name := LineEdit.new()
		expression_name.text = document.data.expressions[selected_expression].name
		expression_name.placeholder_text = "Expression name"
		expression_name.text_submitted.connect(func(value):
			if not value.strip_edges().is_empty():
				document.checkpoint()
				document.data.expressions[selected_expression].name = value.strip_edges().left(40)
				_refresh_all()
		)
		inspector.add_child(expression_name)
		inspector.add_child(_button("Delete expression…", _delete_expression, "Remove this expression after confirmation"))
		var restart := CheckBox.new()
		restart.text = "Restart animation on expression change"
		restart.button_pressed = document.data.expressions[selected_expression].get("restart", false)
		restart.toggled.connect(func(v):
			document.checkpoint()
			document.data.expressions[selected_expression].restart = v
		)
		inspector.add_child(restart)
		for entry in [["X offset", "base_x", -512, 512, 1], ["Y offset", "base_y", -512, 512, 1], ["Scale", "base_scale", 0.1, 3, 0.05], ["Rotation", "base_rotation", -180, 180, 1]]:
			_number(inspector, entry[0], float(document.data.get(entry[1], 1.0 if entry[1] == "base_scale" else 0.0)), entry[2], entry[3], entry[4], _set_base_value.bind(entry[1]))
		_number(inspector, "Motion strength", float(document.data.motion), 0, 2, 0.05, func(v): _set_project("motion", v))
		var blink := CheckBox.new()
		blink.text = "Automatic blinking"
		blink.button_pressed = document.data.blink
		blink.toggled.connect(func(v): _set_project("blink", v))
		inspector.add_child(blink)
		_number(inspector, "Blink minimum (s)", float(document.data.get("blink_min", 2.5)), 0.5, 15, 0.1, _set_base_value.bind("blink_min"))
		_number(inspector, "Blink maximum (s)", float(document.data.get("blink_max", 5.2)), 0.5, 20, 0.1, _set_base_value.bind("blink_max"))
		_number(inspector, "Blink duration (s)", float(document.data.get("blink_duration", 0.14)), 0.04, 1, 0.01, _set_base_value.bind("blink_duration"))
		_number(inspector, "Dim while silent", float(document.data.get("idle_dim", 0.0)), 0, 0.8, 0.05, _set_base_value.bind("idle_dim"))
		_number(inspector, "Bounce force", float(document.data.get("bounce_force", 80)), 0, 300, 5, _set_base_value.bind("bounce_force"))
		_number(inspector, "Bounce gravity", float(document.data.get("bounce_gravity", 500)), 100, 2000, 25, _set_base_value.bind("bounce_gravity"))
		var bounce_costume := CheckBox.new()
		bounce_costume.text = "Bounce on costume change"
		bounce_costume.button_pressed = document.data.get("bounce_on_costume", false)
		bounce_costume.toggled.connect(func(v): _set_project("bounce_on_costume", v))
		inspector.add_child(bounce_costume)
		inspector.add_child(_button("Reset motion", func(): avatar.reset_motion()))
	var property_count := inspector.get_child_count()
	_section(inspector, "Microphone")
	device_picker = OptionButton.new()
	device_picker.custom_minimum_size.x = 220
	device_picker.clip_text = true
	inspector.add_child(device_picker)
	_refresh_devices()
	device_picker.item_selected.connect(func(index):
		if mic.active:
			mic.start(device_picker.get_item_text(index))
	)
	var mic_row := HBoxContainer.new()
	inspector.add_child(mic_row)
	mic_row.add_child(_button("Stop mic" if mic.active else "Enable mic", _toggle_mic))
	mic_row.add_child(_button("Restart", func():
		var selected := device_picker.get_item_text(device_picker.selected) if device_picker.selected >= 0 else "Default"
		mic.stop()
		mic.start(selected)
		if not mic.last_error.is_empty(): _message(mic.last_error)
		_refresh_inspector()
	, "Restart microphone capture if the operating system changed or disconnected the device"))
	mic_row.add_child(_button("Calibrate", _start_calibration))
	meter = ProgressBar.new()
	meter.min_value = -80
	meter.max_value = 0
	meter.value = -80
	meter.show_percentage = false
	meter.custom_minimum_size.y = 10
	inspector.add_child(meter)
	db_label = _label("−96 dBFS", 11, "a9b3a0")
	inspector.add_child(db_label)
	_number(inspector, "Start threshold (dB)", float(document.data.threshold), -75, -5, 1, func(v): _set_project("threshold", v))
	_number(inspector, "Hold (seconds)", float(document.data.hold), 0, 1, 0.02, func(v): _set_project("hold", v))
	var mute := CheckBox.new()
	mute.text = "Mute avatar mouth"
	mute.tooltip_text = "Does not mute your microphone in OBS"
	mute.button_pressed = avatar_muted
	mute.toggled.connect(func(v): avatar_muted = v)
	inspector.add_child(mute)
	var ptt := CheckBox.new()
	ptt.text = "Push-to-talk gate"
	ptt.tooltip_text = "Hold Space while focused, or Ctrl+Alt+Space with background hotkeys enabled"
	ptt.button_pressed = ptt_enabled
	ptt.toggled.connect(func(v): ptt_enabled = v)
	inspector.add_child(ptt)
	var global_toggle := CheckBox.new()
	global_toggle.text = "Background hotkeys (Windows)"
	global_toggle.button_pressed = global_input.active
	global_toggle.tooltip_text = "Ctrl+Alt+1–9: expression · Ctrl+Alt+M: mute · Ctrl+Alt+B: blink · Ctrl+Alt+Space: PTT"
	global_toggle.toggled.connect(func(enabled):
		if enabled:
			var error: String = _start_shortcuts()
			if not error.is_empty():
				_message(error)
				global_toggle.set_pressed_no_signal(false)
		else:
			global_input.stop()
	)
	inspector.add_child(global_toggle)
	mic_status = _label("Microphone is off", 11, "8e98a5")
	inspector.add_child(mic_status)
	var audio_end := inspector.get_child_count()
	_section(inspector, "Output")
	var output_mode := OptionButton.new()
	for caption in ["Transparent background", "Green background", "Magenta background", "Custom color"]:
		output_mode.add_item(caption)
	output_mode.item_selected.connect(_set_output_background)
	output_mode.select(output_background_index)
	inspector.add_child(output_mode)
	var capture_color := ColorPickerButton.new()
	capture_color.text = "Choose custom background"
	capture_color.color = Color(str(document.data.get("output_background", output_custom_color.to_html(false))))
	capture_color.edit_alpha = false
	capture_color.color_changed.connect(func(color):
		document.checkpoint()
		output_custom_color = color
		document.data.output_background = color.to_html(false)
		if output_background_index == 3 and is_instance_valid(output_background): output_background.color = color
	)
	inspector.add_child(capture_color)
	var fps := OptionButton.new()
	for value in [20, 30, 60, 120]: fps.add_item(str(value) + " fps", value)
	fps.select(maxi(0, fps.get_item_index(int(document.data.fps))))
	fps.item_selected.connect(func(i):
		_set_project("fps", fps.get_item_id(i))
		Engine.max_fps = int(document.data.fps)
	)
	inspector.add_child(fps)
	var top := CheckBox.new()
	top.text = "Output always on top"
	top.button_pressed = output_topmost
	top.toggled.connect(func(v):
		output_topmost = v
		if is_instance_valid(output_window):
			output_window.always_on_top = v
	)
	inspector.add_child(top)
	var resolution := OptionButton.new()
	for size_px in [256, 512, 1024, 2048]:
		resolution.add_item(str(size_px) + " × " + str(size_px))
	resolution.select([256, 512, 1024, 2048].find(int(document.data.get("output_size", 512))))
	resolution.item_selected.connect(func(i):
		_set_project("output_size", [256, 512, 1024, 2048][i])
		_apply_render_settings()
	)
	inspector.add_child(_label("Capture resolution", 12))
	inspector.add_child(resolution)
	var pixels := CheckBox.new()
	pixels.text = "Crisp pixel-art filtering"
	pixels.button_pressed = document.data.get("pixel_art", false)
	pixels.toggled.connect(func(v):
		_set_project("pixel_art", v)
		_apply_render_settings()
	)
	inspector.add_child(pixels)
	_section(inspector, "Local WebSocket control")
	_number(inspector, "Local port", control_port, 1024, 65535, 1, func(v): control_port = int(v))
	inspector.add_child(_button("Stop control server" if control_server.active else "Start control server", func():
		if control_server.active:
			control_server.stop()
		else:
			var error: String = control_server.start(control_port)
			if not error.is_empty():
				_message(error)
		_refresh_inspector()
	))
	if control_server.active:
		inspector.add_child(_label("ws://127.0.0.1:" + str(control_server.port), 12))
		inspector.add_child(_button("Copy connection details", func():
			DisplayServer.clipboard_set(JSON.stringify({"url": "ws://127.0.0.1:" + str(control_server.port), "token": control_server.token}))
			status.text = "Connection details copied. The token changes when the server restarts."
		))
	var output_end := inspector.get_child_count()
	_build_performance_inspector()
	for index in range(inspector.get_child_count()):
		var group := 0 if index < property_count else (1 if index < audio_end else (2 if index < output_end else 3))
		inspector.get_child(index).visible = group == inspector_tab
	if shell != null: shell.route_inspector(property_count, audio_end, output_end)
	updating = false

func _build_layer_inspector() -> void:
	var layer: Dictionary = document.data.layers[selected_layer]
	inspector.add_child(_label("Part settings", 12, "aeb6c0"))
	var name_field := LineEdit.new()
	name_field.text = layer.name
	name_field.text_submitted.connect(func(value):
		_set_layer("name", value)
		_refresh_all()
	)
	inspector.add_child(name_field)
	var visibility := CheckBox.new()
	visibility.text = "Visible"
	visibility.button_pressed = layer.visible
	visibility.toggled.connect(func(v): _set_layer("visible", v))
	inspector.add_child(visibility)
	var tint := ColorPickerButton.new()
	tint.text = "Part color tint"
	tint.color = Color(str(layer.get("tint", "ffffff")))
	tint.edit_alpha = true
	tint.color_changed.connect(func(color): _set_layer("tint", color.to_html(true)))
	inspector.add_child(tint)
	for toggle in [["Lock canvas position", "locked"], ["Mirror horizontally", "flip_x"], ["Mirror vertically", "flip_y"], ["Spring follow-through", "spring"], ["Loop animation", "loop"], ["Position spring", "spring_position"], ["Rotation spring", "spring_rotation"], ["Ignore body bounce", "ignore_bounce"], ["Clip linked layers to this image", "clip_children"]]:
		var control := CheckBox.new()
		control.text = toggle[0]
		control.button_pressed = layer.get(toggle[1], toggle[1] in ["loop", "spring_position", "spring_rotation"])
		control.toggled.connect(_set_layer.bind(toggle[1]))
		inspector.add_child(control)
	for entry in [["X offset", "x", -512, 512, 1], ["Y offset", "y", -512, 512, 1], ["Scale", "scale", 0.05, 4, 0.05], ["Width scale", "scale_x", 0.05, 4, 0.05], ["Height scale", "scale_y", 0.05, 4, 0.05], ["Rotation", "rotation", -180, 180, 1], ["Pivot X", "pivot_x", -2048, 2048, 1], ["Pivot Y", "pivot_y", -2048, 2048, 1], ["Opacity", "opacity", 0, 1, 0.05], ["Sway X", "sway", 0, 60, 1], ["Float Y", "float_y", 0, 60, 1], ["Sway speed X", "sway_speed", 0, 12, 0.1], ["Sway speed Y", "sway_speed_y", 0, 12, 0.1], ["Wave phase", "phase", -6.28, 6.28, 0.05], ["Rotation min", "rotation_min", -360, 360, 1], ["Rotation max", "rotation_max", -360, 360, 1], ["Rotation drag", "rotation_drag", -4, 4, 0.1], ["Squash / stretch", "stretch", 0, 2, 0.05], ["Rotation sway", "rotation_sway", 0, 45, 1], ["Bounce", "bounce", 0, 60, 1], ["Spring frequency", "spring_frequency", 0.5, 12, 0.1], ["Spring damping", "damping", 0.1, 2, 0.05], ["Pointer follow range", "pointer_range", 0, 80, 1], ["Sheet columns", "frames", 1, 64, 1], ["Sheet rows", "rows", 1, 64, 1], ["Animation fps", "fps", 0, 30, 1]]:
		if not layer.has(entry[1]):
			layer[entry[1]] = document.new_layer("").get(entry[1], layer.get("sway_speed", 2.1) if entry[1] == "sway_speed_y" else 0.0)
		_number(inspector, entry[0], float(layer[entry[1]]), entry[2], entry[3], entry[4], _set_layer.bind(entry[1]), true)
	for rule in [["Speech visibility", "talk_rule", ["Any speech state", "While talking", "While silent"]], ["Eye visibility", "blink_rule", ["Any eye state", "While blinking", "While eyes open"]]]:
		inspector.add_child(_label(rule[0], 12))
		var picker := OptionButton.new()
		for caption in rule[2]: picker.add_item(caption)
		picker.select(int(layer.get(rule[1], 0)))
		picker.item_selected.connect(func(i):
			_set_layer(rule[1], i)
			layer.condition = 0
		)
		inspector.add_child(picker)
	var condition := OptionButton.new()
	for title in ["Always visible", "While talking", "While silent", "While blinking", "While eyes open"]:
		condition.add_item(title)
	condition.select(int(layer.condition))
	condition.item_selected.connect(func(v): _set_layer("condition", v))
	inspector.add_child(condition)
	var blend := OptionButton.new()
	for caption in ["Normal blend", "Add / glow", "Subtract", "Multiply / shadow"]:
		blend.add_item(caption)
	blend.select(int(layer.get("blend", 0)))
	blend.item_selected.connect(func(i): _set_layer("blend", i))
	inspector.add_child(blend)
	inspector.add_child(_label("Parent · position / rotation / scale", 11, "929ba8"))
	var parent_picker := OptionButton.new()
	parent_picker.add_item("None")
	parent_picker.set_item_metadata(0, "")
	for candidate in document.data.layers:
		if not document.can_parent(layer.id, candidate.id):
			continue
		parent_picker.add_item(candidate.name)
		var item_index := parent_picker.item_count - 1
		parent_picker.set_item_metadata(item_index, candidate.id)
		if candidate.id == layer.parent:
			parent_picker.select(item_index)
	parent_picker.item_selected.connect(func(i): _reparent_layer(parent_picker.get_item_metadata(i)))
	inspector.add_child(parent_picker)
	_build_hotkey_control(layer, 0)
	inspector.add_child(_button("Toggle layer live", _toggle_live_layer.bind(layer.id)))
	inspector.add_child(_button("Replace layer image…", _replace_layer_dialog))

func _number(parent: VBoxContainer, label: String, value: float, minimum: float, maximum: float, step: float, callback: Callable, reverse_args := false) -> void:
	var row := HBoxContainer.new()
	var caption := _label(label, 12)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(caption)
	var number := SpinBox.new()
	number.min_value = minimum
	number.max_value = maximum
	number.step = step
	number.value = value
	number.custom_minimum_size.x = 90
	if reverse_args:
		number.value_changed.connect(func(v): callback.call(v))
	else:
		number.value_changed.connect(callback)
	row.add_child(number)
	parent.add_child(row)

func _set_layer(first: Variant, second: Variant) -> void:
	if updating or selected_layer < 0:
		return
	var key: String = first if first is String else second
	var value: Variant = second if first is String else first
	document.checkpoint()
	var layer: Dictionary = document.data.layers[selected_layer]
	var previous: Variant = layer.get(key)
	layer[key] = value
	var error: String = document.validate(document.data)
	if not error.is_empty():
		if previous == null: layer.erase(key)
		else: layer[key] = previous
		_message(error)
		_refresh_inspector()

func _set_project(key: String, value: Variant) -> void:
	if updating:
		return
	document.checkpoint()
	document.data[key] = value

func _select_layer(index: int) -> void:
	selected_layer = index - 1
	inspector_tab = 0
	inspector_tabs.current_tab = 0
	_refresh_inspector()

func _select_expression(index: int) -> void:
	performance.reset(index)
	selected_expression = index
	_refresh_all()

func _new_expression() -> void:
	if document.data.expressions.size() >= 32:
		_message("This alpha supports up to 32 expressions.")
		return
	name_edit.text = "Expression " + str(document.data.expressions.size() + 1)
	name_dialog.popup_centered(Vector2i(350, 120))
	name_edit.grab_focus()
	name_edit.select_all()

func _create_expression() -> void:
	if name_edit.text.strip_edges().is_empty():
		return
	document.checkpoint()
	var expression: Dictionary = document.data.expressions[selected_expression].duplicate(true)
	expression.name = name_edit.text.strip_edges().left(40)
	document.data.expressions.append(expression)
	selected_expression = document.data.expressions.size() - 1
	performance.reset(selected_expression)
	_refresh_all()

func _choose_slot(slot: String) -> void:
	if importing: return
	import_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	selected_slot = slot
	import_as_layer = false
	import_dialog.popup_file_dialog()

func _add_layer_dialog() -> void:
	if importing: return
	import_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILES
	selected_slot = "new_layer"
	import_as_layer = true
	import_dialog.popup_file_dialog()

func _replace_layer_dialog() -> void:
	if importing: return
	import_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	selected_slot = "replace_layer"
	import_as_layer = true
	import_dialog.popup_file_dialog()

func _import_selected(path: String) -> void:
	if importing:
		return
	if import_as_layer and selected_slot != "replace_layer" and document.data.layers.size() >= 64:
		_message("This alpha supports up to 64 accessory layers.")
		return
	document.checkpoint()
	var target_expression := selected_expression
	var target_layer := selected_layer
	var target_slot := selected_slot
	var target_is_layer := import_as_layer
	var id: String
	if path.get_extension().to_lower() == "gif":
		importing = true
		status.text = "Importing animated GIF…"
		id = await _import_gif(path)
		importing = false
	elif path.get_extension().to_lower() in ["png", "apng", "webp"]:
		var source_file := FileAccess.open(path, FileAccess.READ)
		if source_file != null and source_file.get_length() <= 16 * 1024 * 1024:
			var bytes := source_file.get_buffer(source_file.get_length())
			source_file.close()
			if not AnimatedDecoder.animated_kind(bytes).is_empty():
				importing = true
				status.text = "Decoding animated artwork…"
				id = await _import_container(bytes)
				importing = false
			else:
				id = document.import_image(path)
	else:
		id = document.import_image(path)
	if id.is_empty():
		_message("Could not import this artwork. Static art supports up to 4096 × 4096 / 16 MB. GIF, APNG and animated WebP support up to 256 frames, 2048 × 2048 canvas, and 48 million decoded pixels. See the status bar for decoder details.")
		return
	if target_is_layer:
		if target_slot == "replace_layer" and target_layer >= 0:
			document.data.layers[target_layer].image = id
		else:
			var layer: Dictionary = document.new_layer(path.get_file().get_basename())
			layer.image = id
			var tex: Texture2D = document.texture(id)
			layer.scale = minf(1.0, 240.0 / maxf(tex.get_width(), tex.get_height()))
			document.data.layers.append(layer)
			selected_layer = document.data.layers.size() - 1
	else:
		document.data.expressions[target_expression][target_slot] = id
	if not document.data.has("asset_names"): document.data.asset_names = {}
	document.data.asset_names[id] = path.get_file()
	_remember_folder("artwork", path.get_base_dir())
	status.text = "Imported " + path.get_file() + " · artwork is included when you save."
	_refresh_all()

func _files_dropped(paths: PackedStringArray) -> void:
	for path in paths:
		if path.get_extension().to_lower() == "puppet":
			_request_load(path)
			return
		import_as_layer = true
		selected_slot = "new_layer"
		await _import_selected(path)

func _delete_layer() -> void:
	if selected_layer < 0 or importing:
		return
	document.checkpoint()
	var id: String = document.data.layers[selected_layer].id
	for layer in document.data.layers:
		if layer.parent == id:
			Rig.reparent(document.data.layers, layer, "")
	document.data.layers.remove_at(selected_layer)
	selected_layer -= 1
	_refresh_all()

func _move_layer(direction: int) -> void:
	if selected_layer < 0:
		return
	var destination := selected_layer + direction
	if destination < 0 or destination >= document.data.layers.size():
		return
	document.checkpoint()
	var layer: Dictionary = document.data.layers.pop_at(selected_layer)
	document.data.layers.insert(destination, layer)
	selected_layer = destination
	_refresh_all()

func _undo() -> void:
	if importing:
		return
	if document.undo():
		_restart_shortcuts()
		_refresh_all()

func _redo() -> void:
	if importing:
		return
	if document.redo():
		_restart_shortcuts()
		_refresh_all()

func _save_project() -> void:
	if importing:
		status.text = "Wait for artwork import to finish before saving."
		return
	if current_path.is_empty() or current_path.begins_with("user://"):
		_save_as()
	else:
		_save_to(current_path)

func _save_as() -> void:
	save_dialog.current_file = str(document.data.name).validate_filename() + ".puppet"
	save_dialog.popup_file_dialog()

func _save_to(path: String) -> void:
	if importing:
		status.text = "Wait for artwork import to finish before saving."
		return
	if path.get_extension().to_lower() != "puppet":
		path += ".puppet"
	var old_name: String = document.data.name
	document.data.name = path.get_file().get_basename()
	var error: String = document.save_to(path)
	if not error.is_empty():
		document.data.name = old_name
		pending_quit = false
		_message(error)
	else:
		current_path = path
		_clear_recovery()
		_remember_folder("projects", path.get_base_dir())
		status.text = "Saved portable avatar · " + path
		if pending_quit:
			pending_quit = false
			get_tree().quit()

func _clear_recovery() -> void:
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(session_path + suffix):
			DirAccess.remove_absolute(session_path + suffix)

func _request_load(path: String) -> void:
	if importing:
		status.text = "Wait for artwork import to finish before opening another avatar."
		return
	if document.dirty:
		var confirm := ConfirmationDialog.new()
		confirm.title = "Open another avatar?"
		confirm.dialog_text = "Your current changes are not saved to a project file.\nOpen the other avatar and discard these edits?"
		confirm.confirmed.connect(func():
			_load_project(path)
			confirm.queue_free()
		)
		confirm.canceled.connect(confirm.queue_free)
		add_child(confirm)
		confirm.popup_centered(Vector2i(460, 160))
	else:
		_load_project(path)

func _load_project(path: String) -> void:
	var error: String = document.load_from(path)
	if not error.is_empty():
		_message(error)
		return
	if path == session_path:
		document.dirty = true
	else:
		_clear_recovery()
	_remember_folder("projects", path.get_base_dir())
	current_path = path if not path.begins_with("user://") and not path.begins_with("res://") else ""
	selected_expression = 0
	performance.reset()
	avatar.costume = -1
	avatar.clips_playing = false
	avatar.clips_preview = false
	avatar.clip_time = 0.0
	selected_layer = -1
	avatar.reset_motion()
	avatar.layer_toggles.clear()
	_restart_shortcuts()
	test_talking = false
	talk_button.button_pressed = false
	Engine.max_fps = clampi(int(document.data.fps), 20, 120)
	status.text = "Opened " + path.get_file()
	_refresh_all()

func _refresh_devices() -> void:
	if not is_instance_valid(device_picker):
		return
	var devices := AudioServer.get_input_device_list()
	var current: String = device_picker.get_item_text(device_picker.selected) if device_picker.item_count > 0 and device_picker.selected >= 0 else mic.device_name
	device_picker.clear()
	if not devices.has("Default"):
		devices.insert(0, "Default")
	for device in devices:
		device_picker.add_item(device)
		if device == current:
			device_picker.select(device_picker.item_count - 1)

func _toggle_mic() -> void:
	if mic.active:
		mic.stop()
	else:
		mic.start(device_picker.get_item_text(device_picker.selected))
		if not mic.last_error.is_empty():
			status.text = mic.last_error
	_refresh_inspector()

func _toggle_test() -> void:
	test_talking = talk_button.button_pressed

func _start_calibration() -> void:
	if not mic.active:
		mic.start(device_picker.get_item_text(device_picker.selected))
		if not mic.active:
			_message(mic.last_error)
			return
	calibration_stage = 1
	calibration_time = 0.0
	calibration_levels.clear()
	status.text = "CALIBRATION · Stay quiet for 3 seconds…"
	_refresh_inspector()

func _process(delta: float) -> void:
	if mic == null or avatar == null:
		return
	avatar.expression = performance.update(delta, document.data.expressions.size())
	mic.detector.threshold_db = float(document.data.threshold)
	mic.detector.hold_seconds = float(document.data.hold)
	var gate := not ptt_enabled or global_ptt or (get_window().has_focus() and Input.is_physical_key_pressed(KEY_SPACE))
	avatar.talking = not avatar_muted and (test_talking or (mic.detector.talking and gate))
	var screen_rect := DisplayServer.screen_get_usable_rect(get_window().current_screen)
	if screen_rect.size.x > 0 and screen_rect.size.y > 0:
		avatar.pointer = ((Vector2(DisplayServer.mouse_get_position() - screen_rect.position) / Vector2(screen_rect.size)) * 2.0 - Vector2.ONE).clamp(Vector2(-1, -1), Vector2(1, 1))
	if is_instance_valid(meter):
		meter.value = mic.db
		db_label.text = "%.1f dBFS  ·  %s" % [mic.db, "talking" if avatar.talking else "silent"]
		mic_status.text = ("Audio buffer active · check the level meter" if mic.available else "No samples · check permissions/device") if mic.active else ("No microphone detected" if not mic.last_error.is_empty() else "Microphone is off")
	title_label.text = str(document.data.name) + ("  •" if document.dirty else "")
	if calibration_stage > 0:
		calibration_time += delta
		if mic.available:
			calibration_levels.append(float(mic.db))
		if calibration_time >= 3.0:
			_finish_calibration_step()
	snapshot_time += delta
	if snapshot_time >= 30.0:
		snapshot_time = 0.0
		if document.dirty and not importing:
			var error: String = document.save_to(session_path)
			document.dirty = true
			if not error.is_empty():
				status.text = "Autosave failed: " + error

func _finish_calibration_step() -> void:
	if calibration_levels.is_empty():
		calibration_stage = 0
		_message("No microphone samples arrived. Check the selected device and your system microphone permission.")
		return
	calibration_levels.sort()
	if calibration_stage == 1:
		noise_floor = calibration_levels[int(calibration_levels.size() * 0.8)]
		calibration_levels.clear()
		calibration_stage = 2
		calibration_time = 0.0
		status.text = "CALIBRATION · Speak normally for 3 seconds…"
	else:
		var speech: float = calibration_levels[int(calibration_levels.size() * 0.75)]
		calibration_stage = 0
		if speech - noise_floor < 8.0:
			_message("Speech and background noise are too similar. Move closer to the microphone or lower room noise, then retry. Your threshold has not changed.")
			return
		proposed_threshold = clampf(noise_floor + (speech - noise_floor) * 0.5, -75, -5)
		calibration_dialog.dialog_text = "Room noise: %.1f dBFS\nNormal speech: %.1f dBFS\nSuggested start threshold: %.1f dBFS\n\nYou can fine-tune this later." % [noise_floor, speech, proposed_threshold]
		calibration_dialog.popup_centered(Vector2i(410, 210))
		status.text = "Calibration complete · review the suggested threshold."

func _toggle_output() -> void:
	if is_instance_valid(output_window):
		output_window.queue_free()
		output_window = null
		output_button.text = "Start output"
		status.text = "Output stopped. Your avatar remains available in the preview."
		return
	output_window = Window.new()
	output_window.title = "Puppet Studio — Avatar Output"
	output_window.size = Vector2i(512, 512)
	output_window.min_size = Vector2i(128, 128)
	output_window.transparent_bg = true
	output_window.transparent = true
	output_window.borderless = true
	output_window.unresizable = false
	output_window.always_on_top = output_topmost
	output_window.close_requested.connect(_toggle_output)
	add_child(output_window)
	output_background = ColorRect.new()
	output_custom_color = Color(str(document.data.get("output_background", output_custom_color.to_html(false))))
	output_background.color = [Color.TRANSPARENT, Color("00ff00"), Color("ff00ff"), output_custom_color][output_background_index]
	output_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	output_window.add_child(output_background)
	var image := TextureRect.new()
	image.texture = render_target.get_texture()
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	output_window.add_child(image)
	image.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			DisplayServer.window_start_drag(output_window.get_window_id())
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			get_window().show()
			get_window().grab_focus()
	)
	output_window.position = get_window().position + Vector2i(90, 90)
	output_window.show()
	output_button.text = "Stop output"
	status.text = "Output started · drag the avatar window to move it. OBS compatibility needs testing on your setup."

func _set_output_background(index: int) -> void:
	output_background_index = index
	if not is_instance_valid(output_window):
		_toggle_output()
	output_background.color = [Color.TRANSPARENT, Color("00ff00"), Color("ff00ff"), output_custom_color][index]

func _set_zoom(value: float) -> void:
	zoom = clampf(value, 0.25, 2.5)
	_resize_preview()

func _set_base_value(value: float, key: String) -> void:
	_set_project(key, value)

func _canvas_input(event: InputEvent) -> void:
	if importing: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var art_point: Vector2 = (event.position - preview_texture.position) * 512.0 / preview_texture.size.x
			if canvas_tool == 0:
				var hit := _pick_layer(art_point)
				if hit >= 0 and hit != selected_layer:
					selected_layer = hit
					layers_list.select(hit + 1)
					_refresh_inspector()
			if selected_layer >= 0 and document.data.layers[selected_layer].get("locked", false): return
			document.checkpoint()
			dragging_art = true
		else:
			dragging_art = false
			_refresh_inspector()
	if event is InputEventMouseMotion and dragging_art and preview_texture.size.x > 0:
		var movement: Vector2 = event.relative * 512.0 / preview_texture.size.x
		if selected_layer >= 0:
			var layer: Dictionary = document.data.layers[selected_layer]
			var parent_transform: Transform2D = avatar.root_transform * Rig.rest_transform(document.data.layers, layer.parent)
			match canvas_tool:
				0:
					movement = parent_transform.basis_xform_inv(movement)
					layer.x += movement.x
					layer.y += movement.y
				1:
					var world: Transform2D = parent_transform * Rig.local_transform(layer)
					Rig.move_pivot(layer, world.basis_xform_inv(movement))
				2: layer.rotation = clampf(float(layer.rotation) + event.relative.x * 0.5, -360, 360)
				3: layer.scale = clampf(float(layer.scale) * exp(event.relative.x * 0.005), 0.05, 4)
		else:
			document.data.base_x = float(document.data.get("base_x", 0)) + movement.x
			document.data.base_y = float(document.data.get("base_y", 0)) + movement.y

func _pick_layer(point: Vector2) -> int:
	for index in range(document.data.layers.size() - 1, -1, -1):
		var layer: Dictionary = document.data.layers[index]
		if not avatar.solver.visible.get(layer.id, false): continue
		var texture: Texture2D = document.texture(layer.image)
		if texture == null: continue
		var transform: Transform2D = avatar.root_transform * avatar.poses.get(layer.id, Transform2D.IDENTITY)
		var local := transform.affine_inverse() * point
		var extent := texture.get_size() / Vector2(maxi(1, int(layer.frames)), maxi(1, int(layer.get("rows", 1))))
		var origin := -extent * 0.5 - Vector2(float(layer.get("pivot_x", 0)), float(layer.get("pivot_y", 0)))
		if Rect2(origin, extent).has_point(local): return index
	return -1

func _duplicate_layer() -> void:
	if selected_layer < 0 or document.data.layers.size() >= 64:
		return
	document.checkpoint()
	var layer: Dictionary = document.data.layers[selected_layer].duplicate(true)
	var original_id: String = layer.id
	layer.id = document.new_layer("").id
	layer.hotkey = 0
	for outfit in document.data.get("costumes", []):
		if outfit.layers.has(original_id): outfit.layers[layer.id] = outfit.layers[original_id]
	layer.name += " copy"
	layer.x += 12
	document.data.layers.insert(selected_layer + 1, layer)
	selected_layer += 1
	_refresh_all()

func _delete_expression() -> void:
	if importing:
		return
	if document.data.expressions.size() <= 1:
		_message("Keep at least one expression in an avatar.")
		return
	document.checkpoint()
	document.data.expressions.remove_at(selected_expression)
	selected_expression = maxi(0, selected_expression - 1)
	performance.reset(selected_expression)
	_refresh_all()

func _import_gif(path: String) -> String:
	var helper := OS.get_executable_path().get_base_dir().path_join("GifDecoder.exe")
	if not FileAccess.file_exists(helper):
		helper = ProjectSettings.globalize_path("res://platform/GifDecoder.exe")
	if not FileAccess.file_exists(helper):
		status.text = "GIF decoder helper is not available on this platform."
		return ""
	var job_dir := ProjectSettings.globalize_path("user://imports/" + str(Time.get_ticks_usec()))
	DirAccess.make_dir_recursive_absolute(job_dir)
	var process_id := OS.create_process(helper, [path, job_dir], false)
	if process_id < 0:
		return ""
	var deadline := Time.get_ticks_msec() + 30000
	while OS.is_process_running(process_id):
		if Time.get_ticks_msec() > deadline:
			OS.kill(process_id)
			return ""
		await get_tree().create_timer(0.05).timeout
	var manifest_path := job_dir.path_join("manifest.json")
	if not FileAccess.file_exists(manifest_path):
		return ""
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not manifest is Dictionary or not manifest.get("frames") is Array:
		return ""
	var frames: Array[String] = []
	var durations: Array[float] = []
	for index in range(manifest.frames.size()):
		var frame_path := job_dir.path_join("frame_%04d.png" % index)
		var frame_id: String = document.import_image(frame_path)
		if frame_id.is_empty():
			return ""
		frames.append(frame_id)
		durations.append(float(manifest.frames[index].milliseconds) / 1000.0)
		DirAccess.remove_absolute(frame_path)
		if index % 4 == 0:
			await get_tree().process_frame
	DirAccess.remove_absolute(manifest_path)
	DirAccess.remove_absolute(job_dir)
	if frames.is_empty():
		return ""
	var clip_id := "clip_" + str(Time.get_ticks_usec())
	document.data.animations[clip_id] = {"frames": frames, "durations": durations}
	return clip_id

func _import_container(bytes: PackedByteArray) -> String:
	var decoder = AnimatedDecoder.new()
	var worker := Thread.new()
	if worker.start(decoder.decode.bind(bytes)) != OK:
		status.text = "Could not start the image decoder."
		return ""
	while worker.is_alive():
		await get_tree().create_timer(0.025).timeout
	var result: Dictionary = worker.wait_to_finish()
	if result.has("error"):
		status.text = str(result.error)
		return ""
	var frames: Array[String] = []
	for index in range(result.frames.size()):
		frames.append(document.add_image(result.frames[index]))
		if index % 4 == 0:
			await get_tree().process_frame
	var clip_id := "clip_" + str(Time.get_ticks_usec())
	document.data.animations[clip_id] = {"frames": frames, "durations": result.durations, "loop_count": result.get("loop_count", 0)}
	return clip_id

func _trigger_expression(index: int, pressed: bool, source: String) -> void:
	if index < 0 or index >= document.data.expressions.size():
		return
	var state: Dictionary = document.data.expressions[index]
	performance.activate(index, int(state.get("trigger_mode", 0)), pressed, float(state.get("reaction_seconds", 2.0)), source)
	avatar.expression = performance.update(0, document.data.expressions.size())

func _global_action(action: String, pressed: bool) -> void:
	if action == "release_all":
		performance.release_source("global")
	elif action.begins_with("layer:") and pressed:
		_toggle_live_layer(action.trim_prefix("layer:"))
	elif action.begins_with("costume:") and pressed:
		_cycle_costume(action.trim_prefix("costume:").to_int())
	elif action == "ptt":
		global_ptt = pressed
	elif action.begins_with("expression:"):
		_trigger_expression(action.trim_prefix("expression:").to_int(), pressed, "global")
	elif pressed:
		if action == "mute":
			avatar_muted = not avatar_muted
			_refresh_inspector()
		elif action == "blink":
			avatar.force_blink()

func _input(event: InputEvent) -> void:
	# Releases must arrive even when a focused UI control consumes key presses.
	if event is InputEventKey and not event.pressed and event.keycode >= KEY_1 and event.keycode <= KEY_9:
		_trigger_expression(event.keycode - KEY_1, false, "keyboard")

func _resize_preview() -> void:
	if not is_instance_valid(preview_area) or not is_instance_valid(preview_texture):
		return
	var side := minf(preview_area.size.x, preview_area.size.y) * zoom
	preview_texture.size = Vector2(side, side)
	preview_texture.position = (preview_area.size - preview_texture.size) * 0.5

func _change_workspace(index: int) -> void:
	view_tabs.select(index)
	left_panel.visible = index != 2
	right_panel.visible = index != 2
	if index == 1:
		selected_layer = -1
		_refresh_all()
	call_deferred("_resize_preview")

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.ctrl_pressed:
		if event.keycode == KEY_D:
			_duplicate_layer()
		elif event.keycode == KEY_S:
			_save_project()
		elif event.keycode == KEY_Z:
			_redo() if event.shift_pressed else _undo()
		return
	if event.keycode in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN] and selected_layer >= 0:
		var layer: Dictionary = document.data.layers[selected_layer]
		if layer.get("locked", false): return
		document.checkpoint()
		var step := 10.0 if event.shift_pressed else 1.0
		layer.x += step * (int(event.keycode == KEY_RIGHT) - int(event.keycode == KEY_LEFT))
		layer.y += step * (int(event.keycode == KEY_DOWN) - int(event.keycode == KEY_UP))
		_refresh_inspector()
	if event.keycode >= KEY_1 and event.keycode <= KEY_9:
		var index: int = event.keycode - KEY_1
		if index < document.data.expressions.size():
			_trigger_expression(index, true, "keyboard")
	if event.keycode >= KEY_F1 and event.keycode <= KEY_F9:
		_cycle_costume(event.keycode - KEY_F1)
	if event.keycode == KEY_B:
		avatar.force_blink()

func _message(text: String) -> void:
	if shell != null and is_instance_valid(shell.asset_window) and shell.asset_window.visible:
		var asset_notice := AcceptDialog.new()
		asset_notice.title = "Puppet Studio"
		asset_notice.dialog_text = text
		shell.asset_window.add_child(asset_notice)
		asset_notice.confirmed.connect(asset_notice.queue_free)
		asset_notice.canceled.connect(asset_notice.queue_free)
		asset_notice.popup_centered(Vector2i(510, 220))
		return
	notice.dialog_text = text
	notice.popup_centered(Vector2i(510, 220))

func _show_obs_help() -> void:
	_message("1. Start output in Puppet Studio.\n2. In OBS, try Game Capture → Capture specific window.\n3. Select ‘Puppet Studio — Avatar Output’ and enable Allow Transparency.\n4. If that does not work, use Window Capture and select a green/magenta output background, then add a Color Key filter in OBS.\n\nKeep the output window running. Capture alpha varies by system and has not yet been certified in this alpha.")

func _show_help() -> void:
	_message("Puppet Studio 0.5.1 alpha\n\nStart with File → New character, or open a .puppet file. Select a part to edit it; use Move, Pivot, Rotate, and Scale directly on the canvas.\n\nShortcuts\n1–9  Expressions\nF1–F9  Costumes\nB  Blink\nSpace  Push to talk\nCtrl+S  Save\nCtrl+Z / Ctrl+Shift+Z  Undo / redo\n\nSaved .puppet files include their artwork. Right-click the output window to return to the editor.\n\nSee Help → System status when microphone, capture, or background shortcuts are not behaving as expected.")

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and performance != null:
		performance.release_source("keyboard")
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if is_instance_valid(output_window):
			var confirmation := ConfirmationDialog.new()
			confirmation.title = "Live output is running"
			confirmation.dialog_text = "Keep the avatar running and hide the editor?\nRight-click the output window to reopen the editor."
			confirmation.ok_button_text = "Keep running"
			confirmation.cancel_button_text = "Quit application"
			confirmation.confirmed.connect(func():
				confirmation.queue_free()
				get_window().hide()
			)
			confirmation.canceled.connect(_quit_app)
			add_child(confirmation)
			confirmation.popup_centered(Vector2i(460, 170))
			return
		_quit_app()

func _quit_app() -> void:
	if importing:
		status.text = "Artwork is still importing. Please close again when it finishes."
		return
	if not document.dirty:
		get_tree().quit()
		return
	var confirmation := ConfirmationDialog.new()
	confirmation.name = "QuitConfirmation"
	confirmation.title = "Save your changes?"
	confirmation.dialog_text = "This character has unsaved changes. Save them before closing?"
	confirmation.ok_button_text = "Save and quit"
	confirmation.cancel_button_text = "Keep editing"
	confirmation.add_button("Discard changes", true, "discard")
	confirmation.confirmed.connect(func():
		confirmation.hide()
		confirmation.queue_free()
		pending_quit = true
		_save_project()
	)
	confirmation.canceled.connect(confirmation.queue_free)
	confirmation.custom_action.connect(func(action):
		if action == "discard":
			_clear_recovery()
			get_tree().quit()
	)
	add_child(confirmation)
	confirmation.popup_centered(Vector2i(470, 170))

func _capture_preview() -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(shot_path)
	print("PREVIEW_CAPTURE ", error, " ", shot_path)
	get_tree().quit()

func _make_sample() -> void:
	for mood in ["Neutral", "Happy", "Sleepy"]:
		var expression := {"name": mood, "idle": "", "talk": "", "blink": "", "talk_blink": ""}
		for slot in ["idle", "talk", "blink", "talk_blink"]:
			var open_mouth: bool = slot in ["talk", "talk_blink"]
			var shut_eyes: bool = slot in ["blink", "talk_blink"] or mood == "Sleepy"
			var eyes := '<path d="M175 222q15 14 30 0 M307 222q15 14 30 0" fill="none" stroke="#333744" stroke-width="8" stroke-linecap="round"/>' if shut_eyes else '<ellipse cx="193" cy="223" rx="9" ry="16" fill="#333744"/><ellipse cx="319" cy="223" rx="9" ry="16" fill="#333744"/><circle cx="195" cy="218" r="3" fill="#fff"/><circle cx="321" cy="218" r="3" fill="#fff"/>'
			var mouth := '<ellipse cx="256" cy="272" rx="19" ry="23" fill="#493f48"/><ellipse cx="256" cy="283" rx="12" ry="8" fill="#d68b8f"/>' if open_mouth else '<path d="M236 262q10 17 20 0q10 17 20 0" fill="none" stroke="#493f48" stroke-width="5" stroke-linecap="round"/>'
			var cheek := "#e5a695" if mood != "Happy" else "#e69187"
			var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512"><path d="M129 463q-9-137 54-169h147q61 38 55 169" fill="#839893" stroke="#394b50" stroke-width="7"/><path d="M175 398v65M338 397v66" stroke="#546f70" stroke-width="7" stroke-linecap="round"/><path d="M135 191L120 64q68 6 103 67h69q30-60 101-68l-18 132q48 148-119 156Q90 343 135 191Z" fill="#e8d9bd" stroke="#555051" stroke-width="7" stroke-linejoin="round"/><path d="M143 97l7 76 45-31Z M365 98l-7 76-44-32Z" fill="#c99e90"/><path d="M229 133l16 43 17-42 16 39 15-43" fill="#b6a383"/><ellipse cx="165" cy="256" rx="24" ry="12" fill="%s"/><ellipse cx="347" cy="256" rx="24" ry="12" fill="%s"/>%s<path d="M247 247q9-8 18 0l-9 9Z" fill="#9c726c"/>%s<path d="M163 333q91 33 185-1l-9 36q-87 28-167-2Z" fill="#466b81" stroke="#344b5e" stroke-width="5"/><path d="M287 363l37 0 18 79-40-6Z" fill="#466b81" stroke="#344b5e" stroke-width="5"/><path d="M310 423l25 2" stroke="#93adb6" stroke-width="4"/></svg>' % [cheek, cheek, eyes, mouth]
			var image := Image.new()
			image.load_svg_from_string(svg)
			expression[slot] = document.add_image(image)
		document.data.expressions.append(expression)
	document.data.name = "Mochi · sample avatar"
	document.dirty = false



func _apply_render_settings() -> void:
	var size_px := int(document.data.get("output_size", 512))
	render_target.size = Vector2i(size_px, size_px)
	avatar.scale = Vector2.ONE * size_px / 512.0
	avatar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if document.data.get("pixel_art", false) else CanvasItem.TEXTURE_FILTER_LINEAR

func _build_performance_inspector() -> void:
	_section(inspector, "Expression triggers")
	inspector.add_child(_label(document.data.expressions[selected_expression].name, 14))
	var mode := OptionButton.new()
	for caption in ["Select on press", "Hold while pressed", "Toggle with neutral", "Timed reaction"]:
		mode.add_item(caption)
	mode.select(int(document.data.expressions[selected_expression].get("trigger_mode", 0)))
	mode.item_selected.connect(func(i):
		document.checkpoint()
		document.data.expressions[selected_expression].trigger_mode = i
		performance.reset(selected_expression)
	)
	inspector.add_child(mode)
	_number(inspector, "Reaction seconds", float(document.data.expressions[selected_expression].get("reaction_seconds", 2.0)), 0.1, 60, 0.1, func(v):
		document.checkpoint()
		document.data.expressions[selected_expression].reaction_seconds = v
	)
	var trigger := Button.new()
	trigger.text = "Test expression trigger"
	trigger.button_down.connect(func(): _trigger_expression(selected_expression, true, "button"))
	trigger.button_up.connect(func(): _trigger_expression(selected_expression, false, "button"))
	inspector.add_child(trigger)
	inspector.add_child(_label("Keys 1–9 · toggle returns to expression 1", 11))
	_section(inspector, "Costumes")
	inspector.add_child(_label("F1–F9 · press again for default", 11))
	var picker := OptionButton.new()
	picker.add_item("Default layer visibility")
	for outfit in document.data.get("costumes", []):
		picker.add_item(outfit.name)
	picker.select(avatar.costume + 1 if avatar.costume < document.data.get("costumes", []).size() else 0)
	picker.item_selected.connect(func(i):
		avatar.costume = i - 1
		avatar.layer_toggles.clear()
		_refresh_inspector()
	)
	inspector.add_child(picker)
	inspector.add_child(_button("New costume from visible layers", _capture_costume))
	if avatar.costume >= 0 and avatar.costume < document.data.get("costumes", []).size():
		var outfit: Dictionary = document.data.costumes[avatar.costume]
		_build_hotkey_control(outfit, 112 + avatar.costume if avatar.costume < 9 else 0)
		var title := LineEdit.new()
		title.text = outfit.name
		title.text_submitted.connect(func(v):
			if not v.strip_edges().is_empty():
				document.checkpoint()
				outfit.name = v.strip_edges().left(40)
				_refresh_inspector()
		)
		inspector.add_child(title)
		for layer in document.data.layers:
			var visible_layer := CheckBox.new()
			visible_layer.text = layer.name
			visible_layer.button_pressed = outfit.layers.get(layer.id, layer.visible)
			visible_layer.toggled.connect(func(v):
				document.checkpoint()
				outfit.layers[layer.id] = v
			)
			inspector.add_child(visible_layer)
		inspector.add_child(_button("Delete costume", func():
			document.checkpoint()
			document.data.costumes.remove_at(avatar.costume)
			avatar.costume = -1
			_refresh_inspector()
		))
	_section(inspector, "Motion clips")
	var transport := HBoxContainer.new()
	transport.add_child(_button("Pause" if avatar.clips_playing else "Play clips", func():
		avatar.clips_playing = not avatar.clips_playing
		avatar.clips_preview = true
		_refresh_inspector()
	))
	transport.add_child(_button("Stop", func():
		avatar.clips_playing = false
		avatar.clips_preview = false
		avatar.clip_time = 0.0
		_refresh_inspector()
	))
	inspector.add_child(transport)
	if selected_layer < 0:
		inspector.add_child(_label("Select an accessory layer to edit its clip.", 11))
		return
	var layer: Dictionary = document.data.layers[selected_layer]
	inspector.add_child(_label(layer.name, 14))
	var clip: Dictionary = layer.get("clip", {"duration": 2.0, "loop": true, "enabled": true, "keys": []})
	_number(inspector, "Duration (s)", float(clip.duration), 0.1, 60, 0.1, func(v):
		for key in clip["keys"]:
			if float(key.time) > v:
				_message("Remove later keyframes before shortening the clip.")
				_refresh_inspector()
				return
		document.checkpoint()
		layer.clip = clip
		clip.duration = v
		key_time = minf(key_time, v)
		_refresh_inspector()
	)
	for entry in [["Enabled", "enabled"], ["Loop clip", "loop"]]:
		var box := CheckBox.new()
		box.text = entry[0]
		box.button_pressed = clip[entry[1]]
		box.toggled.connect(func(v):
			document.checkpoint()
			layer.clip = clip
			clip[entry[1]] = v
		)
		inspector.add_child(box)
	_number(inspector, "Playhead / key time", minf(key_time, float(clip.duration)), 0, float(clip.duration), 0.01, func(v):
		key_time = v
		avatar.clip_time = v
		avatar.clips_playing = false
		avatar.clips_preview = true
	)
	var easing := OptionButton.new()
	for caption in ["Linear transition", "Smooth transition", "Hold until next key"]:
		easing.add_item(caption)
	easing.select(key_ease)
	easing.item_selected.connect(func(i): key_ease = i)
	inspector.add_child(easing)
	for entry in [["Key X", "x", -512, 512, 1], ["Key Y", "y", -512, 512, 1], ["Key rotation", "rotation", -360, 360, 1], ["Key scale", "scale", 0.05, 4, 0.05], ["Key opacity", "opacity", 0, 1, 0.05]]:
		_number(inspector, entry[0], float(layer[entry[1]]), entry[2], entry[3], entry[4], func(v):
			_set_layer(entry[1], v)
			avatar.clips_preview = false
			avatar.clips_playing = false
		)
	inspector.add_child(_button("Record / replace key at playhead", func():
		if clip["keys"].size() >= 128:
			_message("This clip supports up to 128 keys.")
			return
		document.checkpoint()
		layer.clip = clip
		MotionClip.capture(layer, minf(key_time, float(clip.duration)), key_ease)
		_refresh_inspector()
	))
	for key in clip["keys"]:
		var row := HBoxContainer.new()
		row.add_child(_button("%.2f s  ·  %s" % [key.time, ["Linear", "Smooth", "Hold"][int(key.ease)]], func():
			key_time = float(key.time)
			key_ease = int(key.ease)
			document.checkpoint()
			for channel in MotionClip.CHANNELS:
				layer[channel] = key[channel]
			avatar.clip_time = key_time
			avatar.clips_playing = false
			avatar.clips_preview = true
			_refresh_inspector()
		))
		row.add_child(_button("×", func():
			document.checkpoint()
			clip["keys"].erase(key)
			_refresh_inspector()
		))
		inspector.add_child(row)

func _capture_costume() -> void:
	if document.data.get("costumes", []).size() >= 32:
		_message("Use no more than 32 costumes.")
		return
	document.checkpoint()
	if not document.data.has("costumes"):
		document.data.costumes = []
	var visibility: Dictionary = {}
	for layer in document.data.layers:
		var outfits: Array = document.data.get("costumes", [])
		visibility[layer.id] = outfits[avatar.costume].layers.get(layer.id, layer.visible) if avatar.costume >= 0 and avatar.costume < outfits.size() else layer.visible
	document.data.costumes.append({"name": "Costume " + str(document.data.costumes.size() + 1), "layers": visibility})
	avatar.costume = document.data.costumes.size() - 1
	_refresh_inspector()

func _cycle_costume(index: int) -> void:
	if index < 0 or index >= document.data.get("costumes", []).size():
		return
	avatar.costume = -1 if avatar.costume == index else index
	avatar.layer_toggles.clear()
	_refresh_inspector()

func _validate_remote_command(payload: Dictionary) -> String:
	if payload.action == "expression" and int(payload.index) >= document.data.expressions.size():
		return "Expression does not exist"
	if payload.action == "costume" and int(payload.index) >= document.data.get("costumes", []).size():
		return "Costume does not exist"
	return ""

func _remote_command(payload: Dictionary) -> void:
	match payload.action:
		"expression": performance.reset(int(payload.index))
		"costume":
			avatar.costume = int(payload.index)
			avatar.layer_toggles.clear()
		"mute": avatar_muted = payload.enabled
		"blink": avatar.force_blink()
		"clips":
			avatar.clips_playing = payload.enabled
			avatar.clips_preview = payload.enabled
			if payload.enabled:
				avatar.clip_time = 0.0
		"reset":
			avatar.layer_toggles.clear()
			performance.reset()
			avatar.costume = -1
			avatar_muted = false
			avatar.clips_playing = false
			avatar.clips_preview = false
	# Refresh only on a command, never each render frame.
	_refresh_inspector()

func _reparent_layer(parent: String) -> void:
	if selected_layer < 0: return
	var layer: Dictionary = document.data.layers[selected_layer]
	if not document.can_parent(layer.id, parent): return
	document.checkpoint()
	var previous: Dictionary = document.data.duplicate(true)
	Rig.reparent(document.data.layers, layer, parent)
	var error: String = document.validate(document.data)
	if not error.is_empty():
		document.data = previous
		_message(error)
	avatar.reset_motion()
	_refresh_all()

func _import_many(paths: PackedStringArray) -> void:
	if importing: return
	for path in paths:
		import_as_layer = true
		selected_slot = "new_layer"
		await _import_selected(path)

func _remember_folder(kind: String, folder: String) -> void:
	if folder.begins_with("user://") or folder.begins_with("res://"): return
	var config := ConfigFile.new()
	config.load("user://workspace.cfg")
	config.set_value("folders", kind, folder)
	config.save("user://workspace.cfg")

func _legacy_new_layered_character() -> void:
	if importing: return
	var confirmation := ConfirmationDialog.new()
	confirmation.title = "New layered character"
	confirmation.dialog_text = "Start a blank character? Save your current avatar first if you want to keep it."
	confirmation.confirmed.connect(func():
		document.fresh()
		document.data.expressions.append({"name": "Neutral", "idle": "", "talk": "", "blink": "", "talk_blink": ""})
		performance.reset()
		avatar.costume = -1
		avatar.clips_playing = false
		avatar.clips_preview = false
		avatar.reset_motion()
		selected_layer = -1
		selected_expression = 0
		current_path = ""
		document.dirty = true
		_refresh_all()
		status.text = "New character · Add body, head, eyes and mouth images. Attach parts with the Parent control."
		confirmation.queue_free()
	)
	confirmation.canceled.connect(confirmation.queue_free)
	add_child(confirmation)
	confirmation.popup_centered(Vector2i(460, 160))

func _toggle_live_layer(id: String) -> void:
	avatar.layer_toggles[id] = not bool(avatar.solver.visible.get(id, false))
	status.text = "Layer visibility toggled for this session. Costume switching resets live toggles."

func _build_hotkey_control(owner: Dictionary, default_key: int) -> void:
	inspector.add_child(_label("Background shortcut (Windows)", 11))
	var row := HBoxContainer.new()
	var modifiers := OptionButton.new()
	for caption in ["None", "Ctrl", "Alt", "Ctrl+Alt", "Shift", "Ctrl+Shift", "Alt+Shift", "Ctrl+Alt+Shift"]:
		modifiers.add_item(caption)
	modifiers.select(int(owner.get("hotkey_mods", 3)))
	row.add_child(modifiers)
	var keys := OptionButton.new()
	keys.add_item("Disabled", 0)
	for vk in range(48, 58): keys.add_item(String.chr(vk), vk)
	for vk in range(65, 91): keys.add_item(String.chr(vk), vk)
	for vk in range(112, 124): keys.add_item("F" + str(vk - 111), vk)
	keys.add_item("Space", 32)
	keys.select(maxi(0, keys.get_item_index(int(owner.get("hotkey", default_key)))))
	keys.item_selected.connect(func(i):
		document.checkpoint()
		owner.hotkey = keys.get_item_id(i)
		_restart_shortcuts()
	)
	modifiers.item_selected.connect(func(i):
		document.checkpoint()
		owner.hotkey_mods = i
		_restart_shortcuts()
	)
	row.add_child(keys)
	inspector.add_child(row)

func _shortcut_configuration() -> Dictionary:
	var entries: Array = []
	for index in range(mini(9, document.data.expressions.size())):
		entries.append(["expression:" + str(index), 49 + index, 3])
	entries.append_array([["mute", 77, 3], ["blink", 66, 3], ["ptt", 32, 3]])
	for index in range(document.data.get("costumes", []).size()):
		var outfit: Dictionary = document.data.costumes[index]
		entries.append(["costume:" + str(index), int(outfit.get("hotkey", 112 + index if index < 9 else 0)), int(outfit.get("hotkey_mods", 3))])
	for layer in document.data.layers:
		entries.append(["layer:" + layer.id, int(layer.get("hotkey", 0)), int(layer.get("hotkey_mods", 3))])
	var seen: Dictionary = {}
	var text := ""
	for entry in entries:
		if entry[1] == 0: continue
		var chord := str(entry[1]) + ":" + str(entry[2])
		if seen.has(chord):
			return {"error": "Shortcut conflict between " + str(seen[chord]) + " and " + str(entry[0]) + ". Change or disable one binding."}
		seen[chord] = entry[0]
		text += "%s,%d,%d;" % entry
	return {"configuration": text}

func _start_shortcuts() -> String:
	var bindings := _shortcut_configuration()
	if bindings.has("error"): return bindings.error
	return global_input.start(bindings.configuration)

func _restart_shortcuts() -> void:
	var bindings := _shortcut_configuration()
	if bindings.has("error"):
		global_input.stop()
		_message(bindings.error)
	elif global_input.active and global_input.configuration != bindings.configuration:
		var error: String = global_input.start(bindings.configuration)
		if not error.is_empty(): _message(error)


func _export_artwork(folder: String) -> void:
	var target := folder.path_join(str(document.data.name).validate_filename() + "-artwork-" + str(Time.get_unix_time_from_system()).replace(".", "-"))
	if DirAccess.make_dir_recursive_absolute(target) != OK:
		_message("Could not create the artwork folder.")
		return
	for id in document.data.assets:
		var file := FileAccess.open(target.path_join(id + ".png"), FileAccess.WRITE)
		if file == null:
			_message("Could not write artwork. Check free space and folder permissions.")
			return
		file.store_buffer(Marshalls.base64_to_raw(document.data.assets[id]))
		file.close()
	var manifest := FileAccess.open(target.path_join("artwork-map.json"), FileAccess.WRITE)
	if manifest == null:
		_message("Artwork images were exported, but the artwork map could not be written.")
		return
	manifest.store_string(JSON.stringify({"expressions": document.data.expressions, "layers": document.data.layers, "animations": document.data.get("animations", {})}, "  "))
	manifest.close()
	status.text = "Exported original embedded PNG artwork and animation map to " + target


func _new_layered_character() -> void:
	shell.wizard_mode = 1
	shell.open_wizard()

extends Control

const Document = preload("res://core/document.gd")
const Microphone = preload("res://core/microphone.gd")
const Avatar = preload("res://runtime/avatar.gd")
const Checker = preload("res://ui/checker.gd")
const GlobalInput = preload("res://platform/global_input.gd")
const AnimatedDecoder = preload("res://core/animated_decoder.gd")
var global_input
var global_ptt := false
var dragging_art := false
var output_topmost := false
var output_background_index := 0
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
var shot_path := ""
var view_tabs: OptionButton
var left_panel: Control
var right_panel: Control

func _ready() -> void:
	Engine.max_fps = 60
	get_window().min_size = Vector2i(1080, 680)
	get_tree().auto_accept_quit = false
	_build_theme()
	document.fresh()
	_make_sample()
	mic = Microphone.new()
	add_child(mic)
	mic.devices_changed.connect(_refresh_devices)
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
	var skin := Theme.new()
	skin.default_font_size = 14
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
	box.bg_color = Color(fill)
	box.border_color = Color(border)
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
	parent.add_child(_label(text.to_upper(), 11, "9bA2af"))

func _spacer(parent: Container) -> void:
	var space := Control.new()
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(space)

func _panel(width: float = 0) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = width
	return panel

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("1c1f24")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 8)
	add_child(margin)
	var root := VBoxContainer.new()
	margin.add_child(root)
	var menubar := HBoxContainer.new()
	root.add_child(menubar)
	menubar.add_child(_label("PUPPET STUDIO", 13, "e3e5db"))
	menubar.add_child(_label(" /  0.2 ALPHA", 11, "7f8794"))
	menubar.add_child(VSeparator.new())
	menubar.add_child(_button("Open…", func(): load_dialog.popup_centered_ratio(0.65)))
	menubar.add_child(_button("Save", _save_project, "Ctrl+S • Portable project with embedded artwork"))
	menubar.add_child(_button("Save as…", _save_as))
	menubar.add_child(_button("Undo", _undo, "Ctrl+Z"))
	menubar.add_child(_button("Redo", _redo, "Ctrl+Shift+Z"))
	_spacer(menubar)
	menubar.add_child(_button("OBS setup", _show_obs_help))
	menubar.add_child(_button("Help", _show_help))
	var toolbar := HBoxContainer.new()
	root.add_child(toolbar)
	title_label = _label("Untitled avatar", 16)
	toolbar.add_child(title_label)
	_spacer(toolbar)
	view_tabs = OptionButton.new()
	for mode in ["Studio workspace", "Quick setup", "Perform / clean preview"]:
		view_tabs.add_item(mode)
	view_tabs.item_selected.connect(_change_workspace)
	toolbar.add_child(view_tabs)
	output_button = _button("Start output", _toggle_output, "Open a separate, clean capture window")
	output_button.add_theme_stylebox_override("normal", _box("667653", "8f9e76"))
	toolbar.add_child(output_button)
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(split)
	left_panel = _panel(210)
	split.add_child(left_panel)
	var left := VBoxContainer.new()
	left_panel.add_child(left)
	left.add_child(_label("LAYERS", 11, "a1a8b4"))
	left.add_child(_label("Base artwork + accessories", 12, "878f9d"))
	layers_list = ItemList.new()
	layers_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layers_list.custom_minimum_size.y = 180
	layers_list.item_selected.connect(_select_layer)
	left.add_child(layers_list)
	var layer_actions := HBoxContainer.new()
	left.add_child(layer_actions)
	layer_actions.add_child(_button("+ Image", _add_layer_dialog))
	layer_actions.add_child(_button("−", _delete_layer, "Delete selected accessory"))
	layer_actions.add_child(_button("↑", func(): _move_layer(-1), "Move down in draw order"))
	layer_actions.add_child(_button("↓", func(): _move_layer(1), "Move up in draw order"))
	left.add_child(_button("Duplicate selected layer", _duplicate_layer, "Copy artwork and properties; editable with Undo"))
	_section(left, "Expression artwork")
	for slot in ["idle", "talk", "blink", "talk_blink"]:
		var caption: String = {"idle": "Idle / eyes open", "talk": "Talking / eyes open", "blink": "Idle / eyes closed", "talk_blink": "Talking / eyes closed"}[slot]
		left.add_child(_button(caption + "…", _choose_slot.bind(slot), "Replace this image in the selected expression"))
	var drop_help := _label("Drop PNG / WebP onto the\nwindow to add an accessory.", 11, "929aa7")
	left.add_child(drop_help)
	var second := HSplitContainer.new()
	second.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(second)
	var center := VBoxContainer.new()
	center.custom_minimum_size.x = 400
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	second.add_child(center)
	var canvas_tools := HBoxContainer.new()
	center.add_child(canvas_tools)
	canvas_tools.add_child(_label("AVATAR CANVAS", 11, "939da9"))
	_spacer(canvas_tools)
	canvas_tools.add_child(_button("−", func(): _set_zoom(zoom - 0.15)))
	canvas_tools.add_child(_button("Fit", func(): _set_zoom(1.0)))
	canvas_tools.add_child(_button("+", func(): _set_zoom(zoom + 0.15)))
	preview_area = Control.new()
	preview_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_area.clip_contents = true
	preview_area.gui_input.connect(_canvas_input)
	center.add_child(preview_area)
	var checker := Checker.new()
	checker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview_area.add_child(checker)
	preview_texture = TextureRect.new()
	preview_texture.texture = render_target.get_texture()
	preview_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_area.add_child(preview_texture)
	preview_area.resized.connect(_resize_preview)
	var tests := HBoxContainer.new()
	center.add_child(tests)
	talk_button = _button("Test talking", _toggle_test, "Preview mouth response without a microphone")
	talk_button.toggle_mode = true
	tests.add_child(talk_button)
	tests.add_child(_button("Blink", func(): avatar.force_blink()))
	_spacer(tests)
	tests.add_child(_label("512 × 512 output  •  alpha", 11, "88919e"))
	var expression_panel := _panel()
	center.add_child(expression_panel)
	var expressions_box := VBoxContainer.new()
	expression_panel.add_child(expressions_box)
	expressions_box.add_child(_label("EXPRESSIONS", 11, "a1a8b4"))
	var expr_scroll := ScrollContainer.new()
	expr_scroll.custom_minimum_size.y = 42
	expressions_box.add_child(expr_scroll)
	expression_bar = HBoxContainer.new()
	expr_scroll.add_child(expression_bar)
	right_panel = _panel(278)
	second.add_child(right_panel)
	var right_column := VBoxContainer.new()
	right_panel.add_child(right_column)
	inspector_tabs = TabBar.new()
	for tab in ["Properties", "Audio", "Output"]:
		inspector_tabs.add_tab(tab)
	inspector_tabs.tab_changed.connect(func(index):
		inspector_tab = index
		_refresh_inspector()
	)
	right_column.add_child(inspector_tabs)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_column.add_child(scroll)
	inspector = VBoxContainer.new()
	inspector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inspector.custom_minimum_size.x = 250
	scroll.add_child(inspector)
	status = _label("Ready. Import your artwork or try the sample character.", 12, "a4adba")
	root.add_child(status)

func _build_dialogs() -> void:
	import_dialog = FileDialog.new()
	import_dialog.title = "Import artwork"
	import_dialog.access = FileDialog.ACCESS_FILESYSTEM
	import_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	import_dialog.filters = PackedStringArray(["*.png,*.apng,*.webp,*.jpg,*.jpeg,*.gif ; Static and animated artwork"])
	import_dialog.file_selected.connect(_import_selected)
	add_child(import_dialog)
	save_dialog = FileDialog.new()
	save_dialog.title = "Save portable avatar"
	save_dialog.access = FileDialog.ACCESS_FILESYSTEM
	save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	save_dialog.filters = PackedStringArray(["*.puppet ; Puppet Studio avatar"])
	save_dialog.file_selected.connect(_save_to)
	add_child(save_dialog)
	load_dialog = FileDialog.new()
	load_dialog.title = "Open avatar"
	load_dialog.access = FileDialog.ACCESS_FILESYSTEM
	load_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	load_dialog.filters = PackedStringArray(["*.puppet ; Puppet Studio avatar"])
	load_dialog.file_selected.connect(_request_load)
	add_child(load_dialog)
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
	selected_expression = clampi(selected_expression, 0, document.data.expressions.size() - 1)
	avatar.expression = selected_expression
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

func _refresh_inspector() -> void:
	updating = true
	for child in inspector.get_children():
		inspector.remove_child(child)
		child.queue_free()
	if selected_layer >= 0:
		_build_layer_inspector()
	else:
		inspector.add_child(_label("CHARACTER", 11, "a1a8b4"))
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
		inspector.add_child(_button("Delete this expression", _delete_expression))
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
			var error: String = global_input.start()
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
	for caption in ["Transparent background", "Green background", "Magenta background"]:
		output_mode.add_item(caption)
	output_mode.item_selected.connect(_set_output_background)
	output_mode.select(output_background_index)
	inspector.add_child(output_mode)
	var fps := OptionButton.new()
	fps.add_item("Smooth · 60 fps")
	fps.add_item("Eco · 30 fps")
	fps.select(1 if int(document.data.fps) == 30 else 0)
	fps.item_selected.connect(func(i):
		_set_project("fps", 30 if i == 1 else 60)
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
	for index in range(inspector.get_child_count()):
		var group := 0 if index < property_count else (1 if index < audio_end else 2)
		inspector.get_child(index).visible = group == inspector_tab
	updating = false

func _build_layer_inspector() -> void:
	var layer: Dictionary = document.data.layers[selected_layer]
	inspector.add_child(_label("LAYER PROPERTIES", 11, "a1a8b4"))
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
	for toggle in [["Lock canvas position", "locked"], ["Mirror horizontally", "flip_x"], ["Mirror vertically", "flip_y"], ["Spring follow-through", "spring"], ["Loop animation", "loop"]]:
		var control := CheckBox.new()
		control.text = toggle[0]
		control.button_pressed = layer.get(toggle[1], toggle[1] == "loop")
		control.toggled.connect(_set_layer.bind(toggle[1]))
		inspector.add_child(control)
	for entry in [["X offset", "x", -512, 512, 1], ["Y offset", "y", -512, 512, 1], ["Scale", "scale", 0.05, 4, 0.05], ["Rotation", "rotation", -180, 180, 1], ["Pivot X", "pivot_x", -2048, 2048, 1], ["Pivot Y", "pivot_y", -2048, 2048, 1], ["Opacity", "opacity", 0, 1, 0.05], ["Sway X", "sway", 0, 60, 1], ["Float Y", "float_y", 0, 60, 1], ["Sway speed", "sway_speed", 0, 12, 0.1], ["Rotation sway", "rotation_sway", 0, 45, 1], ["Bounce", "bounce", 0, 60, 1], ["Spring frequency", "spring_frequency", 0.5, 12, 0.1], ["Spring damping", "damping", 0.1, 2, 0.05], ["Pointer follow range", "pointer_range", 0, 80, 1], ["Sheet columns", "frames", 1, 64, 1], ["Sheet rows", "rows", 1, 64, 1], ["Animation fps", "fps", 0, 30, 1]]:
		if not layer.has(entry[1]):
			layer[entry[1]] = document.new_layer("")[entry[1]]
		_number(inspector, entry[0], float(layer[entry[1]]), entry[2], entry[3], entry[4], _set_layer.bind(entry[1]), true)
	var condition := OptionButton.new()
	for title in ["Always visible", "While talking", "While silent", "While blinking", "While eyes open"]:
		condition.add_item(title)
	condition.select(int(layer.condition))
	condition.item_selected.connect(func(v): _set_layer("condition", v))
	inspector.add_child(condition)
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
	parent_picker.item_selected.connect(func(i): _set_layer("parent", parent_picker.get_item_metadata(i)))
	inspector.add_child(parent_picker)
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
	document.data.layers[selected_layer][key] = value

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
	_refresh_all()

func _choose_slot(slot: String) -> void:
	selected_slot = slot
	import_as_layer = false
	import_dialog.popup_centered_ratio(0.65)

func _add_layer_dialog() -> void:
	selected_slot = "new_layer"
	import_as_layer = true
	import_dialog.popup_centered_ratio(0.65)

func _replace_layer_dialog() -> void:
	selected_slot = "replace_layer"
	import_as_layer = true
	import_dialog.popup_centered_ratio(0.65)

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
			layer.parent = ""
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
		_refresh_all()

func _redo() -> void:
	if importing:
		return
	if document.redo():
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
	save_dialog.popup_centered_ratio(0.65)

func _save_to(path: String) -> void:
	if importing:
		status.text = "Wait for artwork import to finish before saving."
		return
	if not path.ends_with(".puppet"):
		path += ".puppet"
	var old_name: String = document.data.name
	document.data.name = path.get_file().get_basename()
	var error: String = document.save_to(path)
	if not error.is_empty():
		document.data.name = old_name
		_message(error)
	else:
		current_path = path
		status.text = "Saved portable avatar · " + path

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
	current_path = path if not path.begins_with("user://") else ""
	selected_expression = 0
	selected_layer = -1
	avatar.reset_motion()
	test_talking = false
	talk_button.button_pressed = false
	Engine.max_fps = clampi(int(document.data.fps), 30, 60)
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
	output_background.color = [Color.TRANSPARENT, Color("00ff00"), Color("ff00ff")][output_background_index]
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
	output_background.color = [Color.TRANSPARENT, Color("00ff00"), Color("ff00ff")][index]

func _set_zoom(value: float) -> void:
	zoom = clampf(value, 0.25, 2.5)
	_resize_preview()

func _set_base_value(value: float, key: String) -> void:
	_set_project(key, value)

func _canvas_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if selected_layer >= 0 and document.data.layers[selected_layer].get("locked", false):
			return
		dragging_art = event.pressed
		if dragging_art:
			document.checkpoint()
		else:
			_refresh_inspector()
	if event is InputEventMouseMotion and dragging_art and preview_texture.size.x > 0:
		var movement: Vector2 = event.relative * 512.0 / preview_texture.size.x
		if selected_layer >= 0:
			var transform: Transform2D = avatar.root_transform
			var parent: String = document.data.layers[selected_layer].parent
			if avatar.poses.has(parent):
				transform *= avatar.poses[parent]
			movement = transform.basis_xform_inv(movement)
			document.data.layers[selected_layer].x += movement.x
			document.data.layers[selected_layer].y += movement.y
		else:
			document.data.base_x = float(document.data.get("base_x", 0)) + movement.x
			document.data.base_y = float(document.data.get("base_y", 0)) + movement.y

func _duplicate_layer() -> void:
	if selected_layer < 0 or document.data.layers.size() >= 64:
		return
	document.checkpoint()
	var layer: Dictionary = document.data.layers[selected_layer].duplicate(true)
	layer.id = document.new_layer("").id
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

func _global_action(action: String, pressed: bool) -> void:
	if action == "ptt":
		global_ptt = pressed
	elif pressed:
		if action.begins_with("expression:"):
			var index := action.trim_prefix("expression:").to_int()
			if index >= 0 and index < document.data.expressions.size():
				_select_expression(index)
		elif action == "mute":
			avatar_muted = not avatar_muted
			_refresh_inspector()
		elif action == "blink":
			avatar.force_blink()

func _resize_preview() -> void:
	if not is_instance_valid(preview_area) or not is_instance_valid(preview_texture):
		return
	var side := minf(preview_area.size.x, preview_area.size.y) * zoom
	preview_texture.size = Vector2(side, side)
	preview_texture.position = (preview_area.size - preview_texture.size) * 0.5

func _change_workspace(index: int) -> void:
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
		if event.keycode == KEY_S:
			_save_project()
		elif event.keycode == KEY_Z:
			_redo() if event.shift_pressed else _undo()
		return
	if event.keycode >= KEY_1 and event.keycode <= KEY_9:
		var index: int = event.keycode - KEY_1
		if index < document.data.expressions.size():
			_select_expression(index)
	if event.keycode == KEY_B:
		avatar.force_blink()

func _message(text: String) -> void:
	notice.dialog_text = text
	notice.popup_centered(Vector2i(510, 220))

func _show_obs_help() -> void:
	_message("1. Start output in Puppet Studio.\n2. In OBS, try Game Capture → Capture specific window.\n3. Select ‘Puppet Studio — Avatar Output’ and enable Allow Transparency.\n4. If that does not work, use Window Capture and select a green/magenta output background, then add a Color Key filter in OBS.\n\nKeep the output window running. Capture alpha varies by system and has not yet been certified in this alpha.")

func _show_help() -> void:
	_message("PUPPET STUDIO · 0.2.0 ALPHA\n\nReplace expression artwork or add accessory layers. Select a layer, then drag the canvas or use its numeric properties. Sprite sheets use Sheet columns / rows and Animation fps. GIF, APNG and animated WebP can be imported directly.\n\nFocused: 1–9 expressions · B blink · Ctrl+S save · Ctrl+Z undo\nOptional background hotkeys: Ctrl+Alt+1–9 expressions, Ctrl+Alt+M avatar mute, Ctrl+Alt+B blink, Ctrl+Alt+Space PTT. Fixed bindings; conflict detection is not implemented.\n\nThe .puppet file includes your artwork. Autosave runs every 30 seconds while editing. Right-click the live output to restore the editor.\n\nEarly alpha: keyframe editing, costumes, appendage rigs, clipping, and verified OBS compatibility are still in development.")

func _notification(what: int) -> void:
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
	if document.dirty:
		document.save_to(session_path)
	get_tree().quit()

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



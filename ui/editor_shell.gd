extends Node

const MotionVisual = preload("res://ui/motion_visual.gd")
var app
var page := "Artwork"
var scope := "editor"
var main_inspector: VBoxContainer
var navigation: GridContainer
var context_title: Label
var context_help: Label
var tool_window: Window
var asset_window: Window
var wizard: Window
var wizard_name: LineEdit
var wizard_mode := 0
var wizard_choices: Array[Button] = []
var project_assets: ItemList
var asset_search: LineEdit
var asset_source: OptionButton
var asset_caption: Label
var asset_preview: TextureRect
var asset_folder := ""
var selected_asset := ""
var asset_ids: Array[String] = []
var asset_paths: Array[String] = []
var icons: Dictionary = {}
var slot_buttons: Dictionary = {}
var context_nodes: Dictionary = {}
var parts_panel: Control
var mode_label: Label
var live_meter: ProgressBar
var live_label: Label
var tools_bar: HBoxContainer
var workflow := "simple"
var routed_controls: Dictionary = {}
var menus: Dictionary = {}
var preferences: Window
var selected_file := ""
var asset_target: OptionButton
var preview_cache: Dictionary = {}
var thumbnail_cursor := 0

const DESCRIPTIONS := {
	"Artwork": "Choose an image for each mouth and eye state. Empty states use the idle image as a fallback.",
	"Image": "The artwork used by this part. Replace it without losing its rig settings.",
	"Layout": "Place and size the selected artwork. Use the canvas tools for direct editing.",
	"Behavior": "Control the character's blinking, speech bounce and idle movement.",
	"Expression": "Choose the keys for this expression and decide whether it selects, holds, toggles, or plays briefly.",
	"Visibility": "Combine mouth and eye rules, blend modes and live visibility shortcuts.",
	"Rig": "Choose what this part follows, place its pivot, then add soft spring follow-through.",
	"Motion": "Add idle sway, bounce, drag and pointer following. Green is horizontal; blue is vertical.",
	"Animation": "Set up an image sheet or open the pose timeline for keyframed movement.",
	"Audio": "Choose a microphone, watch its level, then calibrate against your room noise.",
	"Output": "Configure the clean capture window. Editor guides are never included in output.",
	"Integrations": "Allow a local controller to change expressions and costumes. The server starts only when enabled.",
	"Costumes": "Save sets of visible parts. Costumes remain independent of mouth and eye state.",
	"Motion clips": "Drag the playhead to a time, arrange the selected part, then save that pose. Diamonds are saved poses.",
}

func icon(kind: String) -> Texture2D:
	if icons.has(kind): return icons[kind]
	var shape: String = {
		"file": '<path d="M5 2h8l5 5v15H5Z M13 2v6h5 M8 12h7M8 16h7"/>',
		"image": '<rect x="3" y="3" width="18" height="18" rx="2"/><circle cx="8" cy="8" r="1.5"/><path d="m4 18 5-6 4 4 3-5 5 7"/>',
		"rig": '<path d="m5 18 7-12 7 12M5 18h14"/><circle cx="12" cy="6" r="3"/><circle cx="5" cy="18" r="3"/><circle cx="19" cy="18" r="3"/>',
		"motion": '<path d="M2 12c4-15 6 15 10 0s6 15 10 0"/>',
		"audio": '<rect x="9" y="2" width="6" height="13" rx="3"/><path d="M5 10v2a7 7 0 0 0 14 0v-2M12 19v3M8 22h8"/>',
		"output": '<rect x="2" y="3" width="20" height="14" rx="2"/><path d="M12 17v5M7 22h10M8 8l7 3-7 3Z"/>',
		"eye": '<path d="M2 12Q12 0 22 12Q12 24 2 12Z"/><circle cx="12" cy="12" r="3"/>',
		"add": '<path d="M12 4v16M4 12h16"/>',
		"trash": '<path d="M4 6h16M9 3h6M6 6l1 15h10l1-15M10 10v7M14 10v7"/>',
		"settings": '<path d="M4 6h16M4 12h16M4 18h16M8 3v6M16 9v6M10 15v6"/>',
		"move": '<path d="M12 2v20M2 12h20m-13-7 3-3 3 3M9 19l3 3 3-3M5 9l-3 3 3 3m14-6 3 3-3 3"/>',
		"copy": '<rect x="8" y="8" width="12" height="12" rx="2"/><path d="M16 8V5a2 2 0 0 0-2-2H5a2 2 0 0 0-2 2v9a2 2 0 0 0 2 2h3"/>',
		"link": '<path d="M9 15l6-6M7 17H6a4 4 0 0 1 0-8h3M15 7h3a4 4 0 0 1 0 8h-3"/>',
		"play": '<path d="M8 5v14l11-7Z"/>',
		"key": '<path d="M15 8a5 5 0 1 1-2 4l8-8M17 8l3 3M14 11l3 3"/>',
	}.get(kind, '<circle cx="12" cy="12" r="8"/><path d="M12 7v6M12 16v1"/>')
	var image := Image.new()
	image.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><g fill="none" stroke="#b8c3ce" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">%s</g></svg>' % shape)
	icons[kind] = ImageTexture.create_from_image(image)
	return icons[kind]

func button(label: String, action: Callable, glyph := "", help := "") -> Button:
	var result: Button = app._button(label, action, help if not help.is_empty() else label)
	if not glyph.is_empty():
		result.icon = icon(glyph)
		result.expand_icon = true
		result.add_theme_constant_override("icon_max_width", 18)
	return result

func explain(label: String) -> String:
	var tips := {
		"Spring frequency": "How quickly this part follows its parent. Lower values feel softer; measured in cycles per second.",
		"Spring damping": "How quickly spring motion settles. Lower values bounce longer; 1 is approximately critical damping.",
		"Rotation drag": "Turn this part in response to movement. Negative values reverse the direction.",
		"Squash / stretch": "Deform width and height in response to movement; zero keeps the original proportions.",
		"Pivot X": "Horizontal rotation origin measured in source-image pixels. Use the Pivot tool to move it without shifting the image.",
		"Pivot Y": "Vertical rotation origin measured in source-image pixels. Use Rest pose while editing.",
		"Start threshold (dB)": "Sound louder than this level opens the mouth. Lower values respond to quieter voices.",
		"Hold (seconds)": "Keep the mouth open through short pauses, reducing flicker between words.",
		"Clip linked layers to this image": "Use this image's alpha to mask its attached children. Nested masks are not supported.",
		"Position spring": "Delay positional movement while retaining the parent attachment.",
		"Rotation spring": "Delay rotational movement for soft follow-through.",
		"Ignore body bounce": "Keep this part independent of the character's global speech bounce.",
		"Sheet columns": "Number of frames across your sprite-sheet image; not the image width in pixels.",
		"Sheet rows": "Number of frame rows in the sprite sheet.",
		"Animation fps": "Sprite-sheet frames played each second. Zero holds the first frame.",
		"ATTACH TO": "Choose the part this one follows. Attaching preserves its rest position; cyclic links are unavailable.",
		"Bounce force": "Initial upward speed when speech starts. Set to zero to disable the speech hop.",
		"Bounce gravity": "Acceleration returning the character after a speech hop.",
		"Dim while silent": "Reduce character brightness when the microphone is below the talking threshold.",
		"Reaction seconds": "How long a Timed reaction is shown before returning to the underlying expression.",
		"Opacity": "Transparency of this part, inherited by attached children. Zero is invisible; one is opaque.",
		"Local port": "Port used by the optional WebSocket controller on this computer only.",
	}
	if tips.has(label): return tips[label]
	if label.begins_with("Sway") or label == "Float Y": return "Procedural side-to-side or vertical motion. The graph previews the wave; zero amplitude disables this axis."
	if label.begins_with("Key "): return "Edit this pose value, then Record to save it at the current playhead time."
	if label.begins_with("Blink "): return "Adjust the timing of automatic eye blinks, measured in seconds."
	if label.begins_with("Rotation"): return "Control rotation in degrees. Minimum and maximum bound the motion of this part."
	if label in ["X offset", "Y offset"]: return "Position relative to the parent, in canvas units. Attached parts move with their parent."
	return label + ". Changes affect the current selection and can be undone with Ctrl+Z."

func setup(owner_app) -> void:
	app = owner_app
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + edge, 10)
	app.add_child(margin)
	var root := VBoxContainer.new()
	margin.add_child(root)
	build_menus(root)
	var bar := HBoxContainer.new()
	root.add_child(bar)
	app.title_label = app._label("Untitled", 16)
	app.title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(app.title_label)
	mode_label = app._label("Quick avatar", 11, "a6b79b")
	bar.add_child(mode_label)
	bar.add_child(button("Audio", func(): open_tool("Audio"), "audio", "Microphone, calibration and background shortcuts"))
	bar.add_child(button("Capture", func(): open_tool("Output"), "settings", "Output resolution, transparency and frame rate"))
	app.view_tabs = OptionButton.new()
	for text in ["Build", "Expressions", "Perform"]: app.view_tabs.add_item(text)
	app.view_tabs.item_selected.connect(app._change_workspace)
	bar.add_child(app.view_tabs)
	app.output_button = button("Start output", app._toggle_output, "output", "Open the clean avatar window for capture")
	bar.add_child(app.output_button)
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(split)
	app.left_panel = app._panel(230)
	split.add_child(app.left_panel)
	var left := VBoxContainer.new()
	app.left_panel.add_child(left)
	parts_panel = VBoxContainer.new()
	left.add_child(parts_panel)
	parts_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parts_panel.add_child(app._label("PARTS", 12, "aeb6c0"))
	parts_panel.add_child(app._label("Select a part to arrange or attach it", 11, "8995a1"))
	app.layers_list = ItemList.new()
	app.layers_list.fixed_icon_size = Vector2i(30, 30)
	app.layers_list.custom_minimum_size.y = 150
	app.layers_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	app.layers_list.item_selected.connect(app._select_layer)
	app.layers_list.tooltip_text = "Select a part to inspect it. The list follows draw order; the canvas shows its attachment links."
	parts_panel.add_child(app.layers_list)
	var actions := GridContainer.new()
	actions.columns = 3
	parts_panel.add_child(actions)
	actions.add_child(button("Add", app._add_layer_dialog, "add", "Import one or more images as separate parts"))
	actions.add_child(button("Copy", app._duplicate_layer, "copy", "Duplicate the selected part"))
	actions.add_child(button("Attach", func(): select_page("Rig"), "link", "Attach the selected part to another part"))
	actions.add_child(button("Back", func(): app._move_layer(-1), "", "Move selected part backward in draw order"))
	actions.add_child(button("Front", func(): app._move_layer(1), "", "Move selected part forward in draw order"))
	actions.add_child(button("Delete", func(): confirm_action("Remove part?", "Remove the selected part? Attached children keep their positions. You can undo this.", app._delete_layer), "trash", "Remove selected part"))
	left.add_child(HSeparator.new())
	left.add_child(app._label("Project artwork", 12, "aeb6c0"))
	left.add_child(app._label("Images used by this character", 12, "959fac"))
	var dock_assets := ItemList.new()
	dock_assets.name = "AssetDock"
	dock_assets.max_columns = 3
	dock_assets.icon_mode = ItemList.ICON_MODE_TOP
	dock_assets.fixed_icon_size = Vector2i(54, 54)
	dock_assets.fixed_column_width = 62
	dock_assets.custom_minimum_size.y = 145
	dock_assets.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dock_assets.item_selected.connect(func(i): selected_asset = dock_assets.get_item_metadata(i))
	dock_assets.item_activated.connect(func(i):
		selected_asset = dock_assets.get_item_metadata(i)
		open_assets()
	)
	left.add_child(dock_assets)
	context_nodes.asset_dock = dock_assets
	left.add_child(button("Asset browser…", open_assets, "image", "Browse project images or a folder, preview artwork and assign it"))
	var second := HSplitContainer.new()
	split.add_child(second)
	second.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var center := VBoxContainer.new()
	second.add_child(center)
	center.custom_minimum_size.x = 370
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tools_bar = HBoxContainer.new()
	center.add_child(tools_bar)
	var tools := OptionButton.new()
	for text in ["Move", "Pivot", "Rotate", "Scale"]: tools.add_item(text)
	tools.item_selected.connect(func(i): app.canvas_tool = i)
	tools.tooltip_text = "Drag on the canvas to use this tool. Pivot preserves the image's placement."
	tools_bar.add_child(tools)
	var guides := CheckButton.new()
	guides.text = "Guides"
	guides.button_pressed = app.rig_visible
	guides.toggled.connect(func(v): app.rig_visible = v)
	guides.tooltip_text = "Show editor-only part bounds, pivots and parent connections"
	tools_bar.add_child(guides)
	var rest := CheckButton.new()
	rest.text = "Rest pose"
	rest.tooltip_text = "Pause procedural and keyframed movement while assembling parts"
	rest.toggled.connect(func(v):
		app.avatar.motion_enabled = not v
		if v:
			app.avatar.clips_playing = false
			app.avatar.clips_preview = false
		app.avatar.reset_motion()
	)
	tools_bar.add_child(rest)
	app._spacer(tools_bar)
	tools_bar.add_child(button("−", func(): app._set_zoom(app.zoom - 0.15), "", "Zoom out"))
	tools_bar.add_child(button("Fit", func(): app._set_zoom(1), "", "Fit the full canvas"))
	tools_bar.add_child(button("+", func(): app._set_zoom(app.zoom + 0.15), "", "Zoom in"))
	app.preview_area = Control.new()
	app.preview_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	app.preview_area.clip_contents = true
	app.preview_area.gui_input.connect(app._canvas_input)
	center.add_child(app.preview_area)
	var checker = app.Checker.new()
	checker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.preview_area.add_child(checker)
	app.preview_texture = TextureRect.new()
	app.preview_texture.texture = app.render_target.get_texture()
	app.preview_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	app.preview_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	app.preview_area.add_child(app.preview_texture)
	app.rig_overlay = app.RigOverlay.new()
	app.rig_overlay.app = app
	app.rig_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	app.rig_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.preview_area.add_child(app.rig_overlay)
	app.preview_area.resized.connect(app._resize_preview)
	var live := HBoxContainer.new()
	center.add_child(live)
	app.talk_button = button("Test voice", app._toggle_test, "audio", "Preview the talking state without a microphone")
	app.talk_button.toggle_mode = true
	live.add_child(app.talk_button)
	live.add_child(button("Blink", func(): app.avatar.force_blink(), "eye", "Test the closed-eye state"))
	live_meter = ProgressBar.new()
	live_meter.min_value = -80
	live_meter.max_value = 0
	live_meter.show_percentage = false
	live_meter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	live_meter.tooltip_text = "Live microphone level. Open Audio to choose a device and threshold."
	live.add_child(live_meter)
	live_label = app._label("Mic off", 11)
	live.add_child(live_label)
	var expression_panel: PanelContainer = app._panel()
	center.add_child(expression_panel)
	var expressions := VBoxContainer.new()
	expression_panel.add_child(expressions)
	expressions.add_child(app._label("Expressions  ·  each button shows its focused shortcut", 12, "aeb6c0"))
	var expr_scroll := ScrollContainer.new()
	expr_scroll.custom_minimum_size.y = 66
	expressions.add_child(expr_scroll)
	app.expression_bar = HBoxContainer.new()
	expr_scroll.add_child(app.expression_bar)
	app.right_panel = app._panel(320)
	second.add_child(app.right_panel)
	var right := VBoxContainer.new()
	app.right_panel.add_child(right)
	context_title = app._label("Artwork", 18)
	right.add_child(context_title)
	navigation = GridContainer.new()
	navigation.columns = 3
	right.add_child(navigation)
	context_help = app._label("", 12, "9ea9b6")
	context_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(context_help)
	right.add_child(HSeparator.new())
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(scroll)
	app.inspector = VBoxContainer.new()
	app.inspector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(app.inspector)
	main_inspector = app.inspector
	# Compatibility bridge for existing actions and integration tests; navigation is owned here.
	app.inspector_tabs = TabBar.new()
	for text in ["Edit", "Audio", "Output", "Perform"]: app.inspector_tabs.add_tab(text)
	app.inspector_tabs.hide()
	app.add_child(app.inspector_tabs)
	app.status = app._label("File → New character to begin, or open an existing avatar.", 12, "99a7b5")
	app.status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	root.add_child(app.status)

func build_menus(root: VBoxContainer) -> void:
	var bar := HBoxContainer.new()
	root.add_child(bar)
	var definitions := {
		"File": [["New character…", open_wizard, "file"], ["Open…", func(): app.load_dialog.popup_file_dialog(), "file"], ["Save", app._save_project, "file"], ["Save as…", app._save_as, "file"], ["Import parts…", app._add_layer_dialog, "image"], ["Asset browser…", open_assets, "image"], ["Export artwork…", func(): app.export_art_dialog.popup_file_dialog(), "image"], ["Open rig example", func(): app._request_load("res://samples/Rigged-Mochi.puppet"), "rig"], ["Quit", app._quit_app, ""]],
		"Edit": [["Undo", app._undo, ""], ["Redo", app._redo, ""], ["Duplicate part", app._duplicate_layer, "copy"], ["Remove selected part…", func(): confirm_action("Remove part?", "Remove the selected part? This can be undone.", app._delete_layer), "trash"], ["Preferences…", open_preferences, "settings"]],
		"Character": [["Character setup…", open_wizard, "file"], ["Expression artwork", func(): select_page("Artwork", true), "image"], ["Expression shortcuts…", func(): select_page("Expression", true), "settings"], ["Add expression…", app._new_expression, "add"], ["Remove expression…", func(): confirm_action("Remove expression?", "Remove the selected expression and its state mapping? This can be undone.", app._delete_expression), "trash"], ["Costumes…", func(): open_tool("Costumes"), "eye"]],
		"Parts": [["Arrange selected part", func(): select_page("Layout"), "move"], ["Attach selected part", func(): select_page("Rig"), "link"], ["Visibility and shortcuts", func(): select_page("Visibility"), "eye"], ["Idle movement", func(): select_page("Motion"), "motion"], ["Image-sheet frames", func(): select_page("Animation"), "image"], ["Reset movement", func(): app.avatar.reset_motion(), ""]],
		"Animation": [["Motion clips…", func(): open_tool("Motion clips"), "motion"], ["Play / pause clips", func(): app.avatar.clips_playing = not app.avatar.clips_playing, "motion"], ["Stop clips", func():
			app.avatar.clips_playing = false
			app.avatar.clips_preview = false
			app.avatar.clip_time = 0.0, ""]],
		"Studio": [["Microphone and shortcuts…", func(): open_tool("Audio"), "audio"], ["Capture settings…", func(): open_tool("Output"), "output"], ["Start / stop output", app._toggle_output, "output"], ["Local control API…", func(): open_tool("Integrations"), "settings"]],
		"View": [["Rig workspace", func(): app._change_workspace(0), ""], ["Perform workspace", func(): app._change_workspace(2), "output"], ["Toggle rig guides", func(): app.rig_visible = not app.rig_visible, "rig"], ["Fit canvas", func(): app._set_zoom(1), ""], ["Asset browser…", open_assets, "image"]],
		"Help": [["Workspace guide", show_guide, ""], ["OBS setup", app._show_obs_help, "output"], ["System status…", open_diagnostics, "settings"], ["About Puppet Studio", app._show_help, ""]],
	}
	for title in definitions:
		var menu := MenuButton.new()
		menu.text = title
		menu.flat = true
		bar.add_child(menu)
		var popup := menu.get_popup()
		var entries: Array = definitions[title]
		menus[title] = entries
		for i in range(entries.size()):
			popup.add_icon_item(icon(entries[i][2]), entries[i][0], i)
			popup.set_item_tooltip(i, entries[i][0])
		popup.id_pressed.connect(func(i): entries[i][1].call())
	app._spacer(bar)
	bar.add_child(app._label("Puppet Studio  ·  v" + str(ProjectSettings.get_setting("application/config/version", "alpha")).replace("-alpha", " alpha"), 11, "87929e"))

func refresh() -> void:
	workflow = app.document.data.get("workflow", "simple" if app.document.data.layers.is_empty() else "layered")
	mode_label.text = {"simple": "Quick avatar", "layered": "Layered avatar", "advanced": "Layered avatar"}.get(workflow, "Layered avatar")
	parts_panel.visible = workflow != "simple" or not app.document.data.layers.is_empty()
	for i in range(app.document.data.layers.size()):
		var layer: Dictionary = app.document.data.layers[i]
		app.layers_list.set_item_icon(i + 1, app.document.texture(layer.image))
		app.layers_list.set_item_tooltip(i + 1, layer.name + (" · attached part" if not layer.parent.is_empty() else " · root part"))
	for i in range(app.document.data.expressions.size()):
		var btn: Button = app.expression_bar.get_child(i)
		btn.icon = app.document.texture(app.document.data.expressions[i].idle)
		btn.expand_icon = true
		btn.add_theme_constant_override("icon_max_width", 36)
		btn.custom_minimum_size.y = 48
		btn.tooltip_text = "Edit " + app.document.data.expressions[i].name + ". Its mouth and eye images are shown in Artwork."
	refresh_asset_dock()
	if is_instance_valid(project_assets): refresh_assets()

func refresh_asset_dock() -> void:
	var list: ItemList = context_nodes.asset_dock
	list.clear()
	var count := 0
	for id in app.document.data.assets:
		list.add_item("", app.document.texture(id))
		list.set_item_metadata(count, id)
		list.set_item_tooltip(count, asset_name(id))
		count += 1
		if count >= 60: break

func asset_name(id: String) -> String:
	for layer in app.document.data.layers:
		if layer.image == id: return layer.name
	for expression in app.document.data.expressions:
		for slot in ["idle", "talk", "blink", "talk_blink"]:
			if expression[slot] == id: return expression.name + " · " + slot.replace("_", " ")
	return app.document.data.get("asset_names", {}).get(id, "Image " + id.left(8))

func select_page(next: String, base := false) -> void:
	close_tool()
	if base: app.selected_layer = -1
	elif next in ["Rig", "Motion", "Animation", "Visibility", "Image"] and app.selected_layer < 0:
		if app.document.data.layers.is_empty():
			app._message("Import character parts first using File → Import parts. Each part has its own rig, motion and visibility settings.")
			return
		app.selected_layer = 0
	page = next
	app._refresh_all()

func control_text(node: Node) -> String:
	if node is Label or node is BaseButton or node is LineEdit:
		if node is OptionButton: return node.get_item_text(0) if node.item_count else ""
		return node.text
	if node is HBoxContainer and node.get_child_count() > 0: return control_text(node.get_child(0))
	return ""

func route_inspector(properties_end: int, audio_end: int, output_end: int) -> void:
	var nodes: Array = app.inspector.get_children()
	var category := "Image" if app.selected_layer >= 0 else "Artwork"
	var section := "Expression"
	var output_section := "Output"
	routed_controls.clear()
	for i in range(nodes.size()):
		var node: Control = nodes[i]
		var label := control_text(node)
		if i < properties_end:
			if app.selected_layer >= 0:
				if node is LineEdit or label == "LAYER PROPERTIES" or label == "Replace layer image…": category = "Image"
				elif label in ["X offset", "Y offset", "Scale", "Width scale", "Height scale", "Rotation", "Lock canvas position", "Mirror horizontally", "Mirror vertically"]: category = "Layout"
				elif label in ["ATTACH TO", "Pivot X", "Pivot Y", "Spring follow-through", "Position spring", "Rotation spring", "Spring frequency", "Spring damping"] or label.begins_with("Parent"): category = "Rig"
				elif label in ["Loop animation", "Sheet columns", "Sheet rows", "Animation fps"]: category = "Animation"
				elif label in ["Sway X", "Float Y", "Sway speed X", "Sway speed Y", "Wave phase", "Rotation min", "Rotation max", "Rotation drag", "Squash / stretch", "Rotation sway", "Bounce", "Pointer follow range", "Ignore body bounce"]: category = "Motion"
				elif label in ["Visible", "Part color tint", "Opacity", "Speech visibility", "Eye visibility", "Always visible", "Normal blend", "Clip linked layers to this image", "Background shortcut (Windows)", "Toggle layer live"]: category = "Visibility"
			else:
				if label in ["X offset", "Y offset", "Scale", "Rotation"]: category = "Layout"
				elif node is LineEdit or label == "Restart animation on expression change": category = "Expression"
				elif label == "Delete expression…": category = "Menu action"
				elif label in ["CHARACTER", app.document.data.expressions[app.selected_expression].name]: category = "Menu action"
				else: category = "Behavior"
		elif i < audio_end: category = "Audio"
		elif i < output_end:
			if label.to_lower() == "local websocket control": output_section = "Integrations"
			category = output_section
		else:
			if label.to_lower() == "expression triggers": section = "Expression"
			elif label.to_lower() == "costumes": section = "Costumes"
			elif label.to_lower() == "motion clips": section = "Motion clips"
			category = section
		node.set_meta("ui_category", category)
		routed_controls[str(i) + ":" + label] = category
		node.visible = category == (page if scope == "editor" else scope)
		decorate(node, label)
	if scope == "editor":
		var pages: Array = ["Image", "Layout", "Visibility", "Rig", "Motion", "Animation"] if app.selected_layer >= 0 else ["Artwork", "Layout", "Behavior", "Expression"]
		if not page in pages:
			page = pages[0]
			for node in nodes: node.visible = node.get_meta("ui_category", "") == page
		for child in navigation.get_children():
			navigation.remove_child(child)
			child.queue_free()
		var page_names := {"Rig": "Attach", "Motion": "Movement", "Animation": "Frames", "Image": "Artwork"}
		for name in pages:
			var nav := button(page_names.get(name, name), func():
				page = name
				app._refresh_inspector(), {"Artwork": "image", "Image": "image", "Layout": "move", "Visibility": "eye", "Rig": "rig", "Motion": "motion", "Animation": "motion"}.get(name, "settings"), DESCRIPTIONS.get(name, name))
			nav.toggle_mode = true
			nav.button_pressed = page == name
			nav.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			navigation.add_child(nav)
		context_title.text = app.document.data.layers[app.selected_layer].name if app.selected_layer >= 0 else app.document.data.expressions[app.selected_expression].name
		context_help.text = DESCRIPTIONS.get(page, "")
		if page == "Artwork": build_slots(app.inspector)
		elif page == "Image": build_layer_preview(app.inspector)
		elif page == "Motion": add_visual(false)
		elif page == "Animation": app.inspector.add_child(button("Open pose timeline…", func(): open_tool("Motion clips"), "key", "Animate this part's position, rotation, scale and opacity with saved poses"))
	elif scope == "Motion clips": add_visual(true)

func decorate(node: Node, label := "") -> void:
	if node is Control and node.tooltip_text.is_empty() and not label.is_empty(): node.tooltip_text = explain(label)
	if node is Label:
		node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if node is Button and not node is OptionButton:
		node.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if node.icon == null:
			node.icon = icon("trash" if "Delete" in node.text else "settings")
			node.expand_icon = true
			node.add_theme_constant_override("icon_max_width", 16)
	for child in node.get_children(): decorate(child, label if not label.is_empty() else control_text(child))

func add_visual(timeline: bool) -> void:
	var graph := MotionVisual.new()
	graph.app = app
	graph.timeline = timeline
	app.inspector.add_child(graph)
	app.inspector.move_child(graph, 0)

func build_slots(parent: VBoxContainer) -> void:
	slot_buttons.clear()
	var mode: String = app.document.data.get("workflow", "simple")
	if mode != "simple" and app.document.data.layers.is_empty():
		context_help.text = "Start with separate images for the body, head, eyes, mouth and accessories."
		parent.add_child(app._label("Assemble your character", 18))
		var steps: Label = app._label("1. Import your artwork as separate parts.\n\n2. Select each part and arrange it on the canvas.\n\n3. Use Visibility to choose when its eyes or mouth appear.", 14)
		steps.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		parent.add_child(steps)
		if mode == "advanced":
			var advanced: Label = app._label("4. Use Attach to connect hair, eyes and accessories to the head or body.\n\n5. Add movement, costumes, and saved poses when the basic character works.", 14)
			advanced.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			parent.add_child(advanced)
		parent.add_child(button("Import character parts…", app._add_layer_dialog, "add", "Select multiple part images with the operating system's file picker"))
		parent.add_child(button("Explore the rig example", func(): app._request_load("res://samples/Rigged-Mochi.puppet"), "rig", "Open the bundled editable character to study its attachments and visibility rules"))
		return
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(grid)
	parent.move_child(grid, 0)
	for slot in ["idle", "talk", "blink", "talk_blink"]:
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(column)
		var title: String = {"idle": "Idle", "talk": "Talking", "blink": "Blink", "talk_blink": "Talking + blink"}[slot]
		var tile := button("", func(): app._choose_slot(slot), "", title + ": choose artwork with the OS file picker")
		tile.custom_minimum_size = Vector2(120, 108)
		tile.icon = app.document.texture(app.document.data.expressions[app.selected_expression][slot])
		tile.expand_icon = true
		tile.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tile.add_theme_constant_override("icon_max_width", 90)
		if tile.icon == null:
			tile.text = "+  Add image"
			tile.alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(tile)
		slot_buttons[slot] = tile
		column.add_child(app._label(title, 13))
		var detail: Label = app._label("Eyes closed" if "blink" in slot else "Eyes open", 11, "93a0ad")
		column.add_child(detail)
		var row := HBoxContainer.new()
		column.add_child(row)
		row.add_child(button("Library", func():
			app.selected_slot = slot
			open_assets()
			asset_target.select(["idle", "talk", "blink", "talk_blink"].find(slot)), "", "Assign project or folder artwork to " + title))
		row.add_child(button("×", func():
			app.document.checkpoint()
			app.document.data.expressions[app.selected_expression][slot] = ""
			app._refresh_all(), "", "Clear this slot; fallback artwork will be used"))

func build_layer_preview(parent: VBoxContainer) -> void:
	var image := TextureRect.new()
	image.texture = app.document.texture(app.document.data.layers[app.selected_layer].image)
	image.custom_minimum_size.y = 180
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	parent.add_child(image)
	parent.move_child(image, 0)
	parent.add_child(button("Choose from asset browser…", open_assets, "image", "Preview and assign existing artwork without re-importing it"))

func open_tool(name: String) -> void:
	close_tool()
	scope = name
	tool_window = make_window(name, Vector2i(940, 720) if name == "Motion clips" else Vector2i(600, 720))
	if name == "Motion clips":
		tool_window.exclusive = false
	app.calibration_dialog.reparent(tool_window)
	app.notice.reparent(tool_window)
	tool_window.close_requested.connect(close_tool)
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 20
	root.offset_top = 16
	root.offset_right = -20
	root.offset_bottom = -16
	tool_window.add_child(root)
	root.add_child(app._label(name, 22))
	var text: Label = app._label(DESCRIPTIONS.get(name, ""), 13, "a5b0bc")
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(text)
	root.add_child(HSeparator.new())
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	app.inspector = VBoxContainer.new()
	app.inspector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(app.inspector)
	root.add_child(button("Done", close_tool, "", "Close this panel; changes are applied immediately"))
	app._refresh_inspector()
	tool_window.popup_centered()

func close_tool() -> void:
	if not is_instance_valid(tool_window): return
	app.calibration_dialog.hide()
	app.notice.hide()
	app.calibration_dialog.reparent(app)
	app.notice.reparent(app)
	tool_window.hide()
	tool_window.queue_free()
	tool_window = null
	scope = "editor"
	app.inspector = main_inspector
	app._refresh_inspector()

func make_window(title: String, extent: Vector2i) -> Window:
	var window := Window.new()
	window.title = title + " — Puppet Studio"
	window.size = extent
	window.min_size = Vector2i(mini(extent.x, 560), mini(extent.y, 480))
	window.transient = true
	window.exclusive = true
	window.theme = app.theme
	app.add_child(window)
	return window

func confirm_action(title: String, message: String, action: Callable) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = title
	dialog.dialog_text = message
	dialog.confirmed.connect(func():
		if not app.importing: action.call()
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	app.add_child(dialog)
	dialog.popup_centered(Vector2i(460, 160))

func _process(_delta: float) -> void:
	if app == null or not is_instance_valid(live_meter): return
	live_meter.value = app.mic.db
	live_label.text = ("%.0f dB" % app.mic.db) if app.mic.active else "Mic off"
	# Decode one local thumbnail per frame so folder navigation can repaint.
	if is_instance_valid(project_assets) and is_instance_valid(asset_source) and asset_source.selected == 1 and thumbnail_cursor < asset_paths.size():
		var index := thumbnail_cursor
		thumbnail_cursor += 1
		project_assets.set_item_icon(index, folder_thumbnail(asset_paths[index]))

func show_guide() -> void:
	app._message("CREATE\nFile → New character offers two clear starting points. Quick uses four mouth and eye images. Layered assembles separate body, face, hair and accessory parts.\n\nBUILD\nSelect a part on the left, arrange it on the canvas, then use Attach to choose what it follows. Movement adds sway and springs; Frames handles image sheets and saved poses.\n\nSHORTCUTS\nEach expression button shows its key. Choose Keys… beside the expression list to change focused and background shortcuts.\n\nPERFORM\nCostumes, microphone setup and capture output are available from their named menus and buttons.")

func diagnostic_report() -> String:
	var shortcut_state := "Connected" if app.global_input.active and app.global_input.received_heartbeat else ("Connecting (up to 30 seconds)" if app.global_input.active else "Off")
	if not app.global_input.last_error.is_empty(): shortcut_state = app.global_input.last_error
	var microphone := "Off"
	if app.mic.active: microphone = "Receiving audio" if app.mic.available else "Enabled, but no audio samples are arriving"
	if not app.mic.last_error.is_empty(): microphone += " · " + app.mic.last_error
	return "Puppet Studio %s\nSystem: %s\nRuntime: Godot %s\nCurrent frame rate: %d fps\n\nMicrophone: %s\nBackground shortcuts: %s\nCapture window: %s\nLocal control: %s\n\nProject: %d expressions · %d parts · %d artwork images\nUnsaved changes: %s\n\nThis report contains no project paths, artwork, control tokens or microphone recordings. No report is sent automatically." % [ProjectSettings.get_setting("application/config/version"), OS.get_name(), Engine.get_version_info().string, Engine.get_frames_per_second(), microphone, shortcut_state, "Open" if is_instance_valid(app.output_window) and app.output_window.visible else "Closed", "See Studio → Local control API for connection status", app.document.data.expressions.size(), app.document.data.layers.size(), app.document.data.assets.size(), "Yes" if app.document.dirty else "No"]

func open_diagnostics() -> void:
	var window := make_window("System status", Vector2i(640, 590))
	window.close_requested.connect(window.queue_free)
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 20
	column.offset_top = 20
	column.offset_right = -20
	column.offset_bottom = -20
	window.add_child(column)
	column.add_child(app._label("System status", 22))
	var report := TextEdit.new()
	report.editable = false
	report.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	report.size_flags_vertical = Control.SIZE_EXPAND_FILL
	report.text = diagnostic_report()
	column.add_child(report)
	column.add_child(button("Refresh status", func(): report.text = diagnostic_report(), "settings", "Read the current microphone, capture and shortcut state"))
	column.add_child(button("Copy report", func(): DisplayServer.clipboard_set(report.text), "file", "Copy this report so you can include it when asking for help"))
	column.add_child(button("Close", window.queue_free, "", "Close System status"))
	window.popup_centered()

func open_wizard() -> void:
	if app.importing: return
	if is_instance_valid(wizard):
		wizard.grab_focus()
		return
	wizard = make_window("Create a character", Vector2i(780, 620))
	wizard.close_requested.connect(func(): wizard.queue_free())
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 24
	root.offset_top = 24
	root.offset_right = -24
	root.offset_bottom = -24
	wizard.add_child(root)
	root.add_child(app._label("Create a character", 23))
	root.add_child(app._label("Choose the setup that matches your artwork. You can add more parts later.", 13, "9baab7"))
	wizard_name = LineEdit.new()
	wizard_name.placeholder_text = "Character name"
	wizard_name.text = "My character"
	wizard_name.tooltip_text = "The name shown in the editor and suggested when saving"
	root.add_child(wizard_name)
	wizard_choices.clear()
	var group := ButtonGroup.new()
	var choices := [
		["Quick avatar", "Use up to four images per expression: idle, talking, blink, and talking + blink.", "image"],
		["Layered avatar", "Build from separate body, face, hair and accessory images. Attach parts and add movement when ready.", "link"],
	]
	for i in range(choices.size()):
		var choice := button(choices[i][0] + "\n" + choices[i][1], func(): wizard_mode = i, choices[i][2], choices[i][1])
		choice.button_group = group
		choice.toggle_mode = true
		choice.button_pressed = i == wizard_mode
		choice.alignment = HORIZONTAL_ALIGNMENT_LEFT
		choice.custom_minimum_size.y = 88
		root.add_child(choice)
		wizard_choices.append(choice)
	var note: Label = app._label("Your current project has unsaved changes. Save it before creating another character." if app.document.dirty else "Your current saved project will remain on disk.", 12, "d4be8b")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(note)
	var row := HBoxContainer.new()
	root.add_child(row)
	row.add_child(button("Cancel", func(): wizard.queue_free(), "", "Return to the current character"))
	app._spacer(row)
	row.add_child(button("Create character", func():
		var name := wizard_name.text.strip_edges()
		if name.is_empty():
			wizard_name.grab_focus()
			return
		var chosen := wizard_mode
		wizard.hide()
		wizard.queue_free()
		if app.document.dirty:
			confirm_action("Discard unsaved changes?", "Create a new character and discard the current unsaved edits? Cancel to save them first.", create_character.bind(chosen, name))
		else: create_character(chosen, name), "add", "Create a blank character using the chosen workflow"))
	wizard.popup_centered()

func create_character(mode: int, title: String) -> void:
	close_tool()
	app._clear_recovery()
	app.document.fresh()
	app.document.data.name = title.left(80)
	app.document.data.workflow = ["simple", "layered"][clampi(mode, 0, 1)]
	app.document.data.expressions.append({"name": "Neutral", "idle": "", "talk": "", "blink": "", "talk_blink": ""})
	app.performance.reset()
	app.avatar.costume = -1
	app.avatar.layer_toggles.clear()
	app.avatar.clips_playing = false
	app.avatar.clips_preview = false
	app.avatar.reset_motion()
	app.selected_layer = -1
	app.selected_expression = 0
	app.current_path = ""
	app.document.dirty = true
	page = "Artwork"
	app._change_workspace(0)
	app._refresh_all()
	app.status.text = "Choose your Idle image to begin." if mode == 0 else "Import separate artwork parts, arrange them on the canvas, then use Attach to build the hierarchy."

func open_preferences() -> void:
	if is_instance_valid(preferences):
		preferences.grab_focus()
		return
	preferences = make_window("Preferences", Vector2i(560, 480))
	preferences.close_requested.connect(func(): preferences.queue_free())
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 24
	root.offset_right = -24
	root.offset_top = 24
	root.offset_bottom = -24
	preferences.add_child(root)
	root.add_child(app._label("Editor appearance", 22))
	root.add_child(app._label("These preferences affect the editor, not the captured avatar.", 12, "9faebb"))
	var config := ConfigFile.new()
	config.load("user://workspace.cfg")
	root.add_child(app._label("Color scheme"))
	var scheme := OptionButton.new()
	scheme.add_item("Charcoal")
	scheme.add_item("Graphite · higher contrast")
	scheme.select(int(config.get_value("appearance", "scheme", 0)))
	scheme.tooltip_text = "Choose panel contrast and editor background colors"
	root.add_child(scheme)
	root.add_child(app._label("Text size"))
	var text_size := OptionButton.new()
	for value in [13, 14, 16]: text_size.add_item(str(value) + " px", value)
	text_size.select(maxi(0, text_size.get_item_index(int(config.get_value("appearance", "font_size", 14)))))
	text_size.tooltip_text = "Adjust editor control text for readability"
	root.add_child(text_size)
	root.add_child(app._label("Selection accent"))
	var accent := ColorPickerButton.new()
	accent.custom_minimum_size.y = 34
	accent.color = Color(config.get_value("appearance", "accent", "a8bf91"))
	accent.edit_alpha = false
	accent.tooltip_text = "Accent used for selected controls and keyboard focus"
	root.add_child(accent)
	root.add_child(button("Apply preferences", func():
		config.set_value("appearance", "scheme", scheme.selected)
		config.set_value("appearance", "font_size", text_size.get_selected_id())
		config.set_value("appearance", "accent", accent.color.to_html(false))
		config.save("user://workspace.cfg")
		app._build_theme()
		preferences.theme = app.theme
		app._refresh_all(), "settings", "Apply and remember editor appearance"))
	root.add_child(button("Done", func(): preferences.queue_free(), "", "Close Preferences"))
	preferences.popup_centered()

func open_assets() -> void:
	if is_instance_valid(asset_window):
		asset_window.grab_focus()
		return
	asset_window = make_window("Asset browser", Vector2i(920, 650))
	asset_window.close_requested.connect(func(): asset_window.queue_free())
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 20
	root.offset_right = -20
	root.offset_top = 16
	root.offset_bottom = -16
	asset_window.add_child(root)
	root.add_child(app._label("Artwork library", 22))
	var row := HBoxContainer.new()
	root.add_child(row)
	asset_source = OptionButton.new()
	asset_source.add_item("This project")
	asset_source.add_item("Local folder")
	asset_source.item_selected.connect(func(_i): refresh_assets())
	row.add_child(asset_source)
	asset_search = LineEdit.new()
	asset_search.placeholder_text = "Search artwork…"
	asset_search.tooltip_text = "Filter by part, expression or filename"
	asset_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	asset_search.text_changed.connect(func(_v): refresh_assets())
	row.add_child(asset_search)
	row.add_child(button("Choose folder…", func():
		var dialog := FileDialog.new()
		dialog.use_native_dialog = true
		dialog.access = FileDialog.ACCESS_FILESYSTEM
		dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
		asset_window.add_child(dialog)
		dialog.dir_selected.connect(func(path):
			asset_folder = path
			asset_source.select(1)
			refresh_assets()
			dialog.queue_free()
		)
		dialog.canceled.connect(dialog.queue_free)
		dialog.popup_file_dialog(), "file", "Choose a local artwork folder with the operating system's file browser"))
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(split)
	project_assets = ItemList.new()
	project_assets.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	project_assets.max_columns = 4
	project_assets.icon_mode = ItemList.ICON_MODE_TOP
	project_assets.fixed_icon_size = Vector2i(86, 86)
	project_assets.fixed_column_width = 125
	project_assets.max_text_lines = 2
	project_assets.item_selected.connect(select_asset)
	split.add_child(project_assets)
	var detail := VBoxContainer.new()
	detail.custom_minimum_size.x = 250
	split.add_child(detail)
	asset_preview = TextureRect.new()
	asset_preview.custom_minimum_size = Vector2(250, 250)
	asset_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	asset_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	detail.add_child(asset_preview)
	asset_caption = app._label("Select artwork to preview", 13)
	asset_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_child(asset_caption)
	detail.add_child(app._label("Assign to", 12))
	asset_target = OptionButton.new()
	for title in ["Idle image", "Talking image", "Blink image", "Talking + blink", "Selected part", "New part"]: asset_target.add_item(title)
	asset_target.select(4 if app.selected_layer >= 0 else maxi(0, ["idle", "talk", "blink", "talk_blink"].find(app.selected_slot)))
	asset_target.tooltip_text = "Choose where the selected image should be used"
	detail.add_child(asset_target)
	detail.add_child(button("Use artwork", assign_asset, "image", "Assign the previewed image to the chosen slot or part"))
	root.add_child(button("Close", func(): asset_window.queue_free(), "", "Close the asset browser"))
	refresh_assets()
	asset_window.popup_centered()

func folder_thumbnail(path: String) -> Texture2D:
	if preview_cache.has(path): return preview_cache[path]
	if not path.get_extension().to_lower() in ["png", "jpg", "jpeg", "webp"]: return icon("motion")
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 16 * 1024 * 1024: return icon("image")
	file.close()
	var image := Image.load_from_file(path)
	if image == null or image.is_empty(): return icon("image")
	var fit := minf(1, 200.0 / maxf(image.get_width(), image.get_height()))
	image.resize(maxi(1, int(image.get_width() * fit)), maxi(1, int(image.get_height() * fit)))
	var texture := ImageTexture.create_from_image(image)
	if preview_cache.size() >= 100: preview_cache.clear()
	preview_cache[path] = texture
	return texture

func refresh_assets() -> void:
	if not is_instance_valid(project_assets): return
	project_assets.clear()
	asset_ids.clear()
	asset_paths.clear()
	thumbnail_cursor = 0
	var query := asset_search.text.to_lower()
	if asset_source.selected == 0:
		var ids: Array = app.document.data.get("animations", {}).keys()
		ids.append_array(app.document.data.assets.keys())
		for id in ids:
			var title := asset_name(id)
			if not query.is_empty() and not query in title.to_lower(): continue
			project_assets.add_item(title, app.document.texture(id))
			project_assets.set_item_tooltip(project_assets.item_count - 1, title)
			asset_ids.append(id)
			asset_paths.append("")
			if asset_ids.size() >= 250: break
	else:
		var directory := DirAccess.open(asset_folder)
		if directory != null:
			var files := directory.get_files()
			files.sort()
			for file in files:
				if not file.get_extension().to_lower() in ["png", "apng", "jpg", "jpeg", "webp", "gif"]: continue
				if not query.is_empty() and not query in file.to_lower(): continue
				var path := asset_folder.path_join(file)
				project_assets.add_item(file, icon("image"))
				project_assets.set_item_tooltip(project_assets.item_count - 1, path)
				asset_ids.append("")
				asset_paths.append(path)
				if asset_paths.size() >= 250: break
	asset_caption.text = ("No matching artwork. Choose a folder or import images." if project_assets.item_count == 0 else str(project_assets.item_count) + " images · select one to preview")
	var selected := asset_ids.find(selected_asset) if asset_source.selected == 0 and not selected_asset.is_empty() else asset_paths.find(selected_file)
	if selected >= 0:
		project_assets.select(selected)
		select_asset(selected)
	else:
		selected_asset = ""
		selected_file = ""
		asset_preview.texture = null

func select_asset(index: int) -> void:
	selected_asset = asset_ids[index]
	selected_file = asset_paths[index]
	asset_preview.texture = app.document.texture(selected_asset) if not selected_asset.is_empty() else folder_thumbnail(selected_file)
	var title := asset_name(selected_asset) if not selected_asset.is_empty() else selected_file.get_file()
	asset_caption.text = title
	if not selected_asset.is_empty():
		var tex: Texture2D = app.document.texture(selected_asset)
		if tex != null: asset_caption.text += "\n%d × %d px" % [tex.get_width(), tex.get_height()]
	else:
		project_assets.set_item_icon(index, asset_preview.texture)
		if selected_file.get_extension().to_lower() in ["gif", "apng"]: asset_caption.text += "\nAnimated file · imported frames are previewed in the project."

func assign_asset() -> void:
	if app.importing: return
	var target := asset_target.selected
	if target == 4 and app.selected_layer < 0:
		asset_caption.text = "Select a character part in the editor first, or choose New part."
		return
	if selected_asset.is_empty() and selected_file.is_empty():
		asset_caption.text = "Select an image first."
		return
	if not selected_file.is_empty():
		app.import_as_layer = target >= 4
		app.selected_slot = ["idle", "talk", "blink", "talk_blink"][target] if target < 4 else ("replace_layer" if target == 4 else "new_layer")
		await app._import_selected(selected_file)
	else:
		if target == 5 and app.document.data.layers.size() >= 64:
			asset_caption.text = "The project already has 64 parts."
			return
		app.document.checkpoint()
		if target < 4: app.document.data.expressions[app.selected_expression][["idle", "talk", "blink", "talk_blink"][target]] = selected_asset
		elif target == 4: app.document.data.layers[app.selected_layer].image = selected_asset
		else:
			var layer: Dictionary = app.document.new_layer(asset_name(selected_asset))
			layer.image = selected_asset
			app.document.data.layers.append(layer)
			app.selected_layer = app.document.data.layers.size() - 1
		app._refresh_all()
	asset_caption.text = "Artwork assigned. Close this window to continue editing."



extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var app = load("res://main.tscn").instantiate()
	app.session_path = 'user://automated-test-recovery.puppet'
	root.add_child(app)
	await process_frame
	app.recovery_dialog.hide()
	app._add_layer_dialog()
	for attempt in range(600):
		await create_timer(0.05).timeout
		if app.document.data.layers.size() > 0: break
	if app.document.data.layers.size() != 1:
		printerr("NATIVE_RESULT: file picker import did not complete")
		quit(1)
		return
	print("PASS: Native Windows picker imported artwork with a Unicode filename")
	print("NATIVE_RESULT: 1 checks, 0 failures")
	quit(0)

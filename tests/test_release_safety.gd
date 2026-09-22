extends SceneTree

const Document = preload("res://core/document.gd")
var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if value: print("PASS: " + message)
	else:
		failures += 1
		printerr("FAIL: " + message)

func _initialize() -> void:
	var doc = Document.new()
	doc.fresh()
	doc.data.name = "猫 — آواز"
	doc.data.workflow = "advanced"
	doc.data.expressions.append({"name": "Neutral", "idle": "", "talk": "", "blink": "", "talk_blink": ""})
	var folder := "user://save-safety-" + str(Time.get_ticks_usec())
	DirAccess.make_dir_absolute(folder)
	var path := folder.path_join("avatar.puppet")
	doc.dirty = true
	check(doc.save_to(path).is_empty(), "Unicode project saves successfully")
	check(not doc.dirty, "Successful save clears dirty state")
	var saved := FileAccess.get_file_as_bytes(path)
	check(saved.size() == JSON.stringify(doc.data).to_utf8_buffer().size(), "Saved length is the UTF-8 byte length")
	var reopened = Document.new()
	check(reopened.load_from(path).is_empty() and reopened.data.name == doc.data.name, "Unicode and workflow survive reopening")
	doc.checkpoint()
	doc.data.name = "Second version"
	check(doc.save_to(path).is_empty(), "Existing project can be replaced")
	check(FileAccess.get_file_as_bytes(path + ".bak") == saved, "Backup preserves the exact prior project")
	var current := FileAccess.get_file_as_bytes(path)
	doc.checkpoint()
	doc.data.workflow = "invalid-mode"
	check(not doc.save_to(path).is_empty(), "Malformed workflow cannot overwrite a project")
	check(FileAccess.get_file_as_bytes(path) == current and doc.dirty, "Rejected save keeps original and unsaved state")
	doc.data.workflow = "advanced"
	doc.data.asset_names = {"asset": 123}
	check(not doc.validate(doc.data).is_empty(), "Non-text artwork names are rejected")
	doc.data.erase("asset_names")
	check(not doc.save_to(folder.path_join("missing/avatar.puppet")).is_empty() and doc.dirty, "Unwritable destination retains unsaved work")
	var broken := FileAccess.open(folder.path_join("broken.puppet"), FileAccess.WRITE)
	broken.store_string("{ incomplete")
	broken.close()
	check(not doc.load_from(folder.path_join("broken.puppet")).is_empty() and doc.data.name == "Second version", "Broken project cannot replace the active document")
	# Remove only the exact temporary files created by this test.
	for suffix in ["avatar.puppet", "avatar.puppet.bak", "broken.puppet"]:
		DirAccess.remove_absolute(folder.path_join(suffix))
	DirAccess.remove_absolute(folder)
	print("SAFETY_RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

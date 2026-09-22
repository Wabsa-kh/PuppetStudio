extends Node

signal action_received(action: String, pressed: bool)
var udp := PacketPeerUDP.new()
var process_id := -1
var token := ""
var configuration := ""
var active := false
var heartbeat_age := 0.0
var received_heartbeat := false
var last_error := ""

func start(bindings := "") -> String:
	last_error = ""
	if OS.get_name() != "Windows":
		return "Global input is currently implemented for Windows only."
	stop()
	var path := OS.get_executable_path().get_base_dir().path_join("InputBridge.exe")
	if not FileAccess.file_exists(path):
		path = ProjectSettings.globalize_path("res://platform/InputBridge.exe")
	if not FileAccess.file_exists(path):
		return "InputBridge.exe is missing. Keep it next to PuppetStudio.exe."
	var error := udp.bind(0, "127.0.0.1")
	if error != OK:
		return "Could not open the local input channel."
	token = Crypto.new().generate_random_bytes(20).hex_encode()
	process_id = OS.create_process(path, [str(udp.get_local_port()), str(OS.get_process_id()), token, bindings], false)
	if process_id < 0:
		udp.close()
		return "Could not start background input."
	configuration = bindings
	active = true
	heartbeat_age = 0.0
	received_heartbeat = false
	return ""

func stop() -> void:
	if process_id > 0 and OS.is_process_running(process_id):
		OS.kill(process_id)
	process_id = -1
	udp.close()
	active = false
	action_received.emit("ptt", false)
	action_received.emit("release_all", false)

func _process(delta: float) -> void:
	if not active:
		return
	heartbeat_age += delta
	var packets := 0
	while udp.get_available_packet_count() > 0 and packets < 64:
		var message := udp.get_packet().get_string_from_utf8().split("|")
		packets += 1
		if message.size() != 3 or message[0] != token:
			continue
		heartbeat_age = 0.0
		received_heartbeat = true
		if message[1] != "heartbeat":
			action_received.emit(message[1], message[2] == "1")
	if process_id > 0 and not OS.is_process_running(process_id):
		last_error = "The shortcut helper stopped. Enable background shortcuts to reconnect."
		stop()
	elif heartbeat_age > (2.0 if received_heartbeat else 30.0):
		last_error = "The shortcut helper did not respond. Enable background shortcuts to retry."
		stop()

func _exit_tree() -> void:
	stop()

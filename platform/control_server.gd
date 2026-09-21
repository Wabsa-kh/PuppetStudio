extends Node

signal command_received(command: Dictionary)
const MAX_CONNECTIONS := 4
var command_validator: Callable
var server := TCPServer.new()
var clients: Array[Dictionary] = []
var token := ""
var active := false
var port := 0

func start(requested_port := 19532) -> String:
	stop()
	if requested_port < 1024 or requested_port > 65535:
		return "Use a port from 1024 to 65535."
	if server.listen(requested_port, "127.0.0.1") != OK:
		return "That local port is already in use. Choose another port."
	token = Crypto.new().generate_random_bytes(24).hex_encode()
	port = requested_port
	active = true
	return ""

func stop() -> void:
	for client in clients:
		client.peer.close()
	clients.clear()
	server.stop()
	active = false
	token = ""
	port = 0

func _process(delta: float) -> void:
	if not active:
		return
	if server.is_connection_available():
		var connection := server.take_connection()
		if clients.size() >= MAX_CONNECTIONS:
			connection.disconnect_from_host()
		else:
			var peer := WebSocketPeer.new()
			peer.inbound_buffer_size = 8192
			peer.outbound_buffer_size = 8192
			peer.max_queued_packets = 16
			if peer.accept_stream(connection) == OK:
				clients.append({"peer": peer, "age": 0.0, "authenticated": false, "budget": 20.0})
	for client in clients.duplicate():
		var peer: WebSocketPeer = client.peer
		peer.poll()
		client.age += delta
		client.budget = minf(20.0, float(client.budget) + delta * 10.0)
		if peer.get_ready_state() == WebSocketPeer.STATE_CLOSED:
			clients.erase(client)
			continue
		if not client.authenticated and client.age > 5:
			peer.close(1008, "Authentication timeout")
			clients.erase(client)
			continue
		var processed := 0
		while peer.get_ready_state() == WebSocketPeer.STATE_OPEN and peer.get_available_packet_count() > 0 and processed < 8:
			processed += 1
			var packet := peer.get_packet()
			if packet.size() > 4096 or not peer.was_string_packet():
				peer.close(1009, "Text messages up to 4096 bytes")
				break
			var payload: Variant = JSON.parse_string(packet.get_string_from_utf8())
			if not payload is Dictionary:
				peer.send_text('{"ok":false,"error":"Expected JSON object"}')
				continue
			if not client.authenticated:
				if payload.get("token", "") != token:
					peer.close(1008, "Invalid token")
					break
				client.authenticated = true
				peer.send_text('{"ok":true,"event":"authenticated","version":1}')
				continue
			if client.budget < 1:
				peer.send_text('{"ok":false,"error":"Rate limit"}')
				continue
			client.budget -= 1
			var error := validate_command(payload)
			if error.is_empty() and command_validator.is_valid():
				error = command_validator.call(payload)
			if not error.is_empty():
				peer.send_text(JSON.stringify({"ok": false, "error": error}))
			else:
				command_received.emit(payload)
				peer.send_text('{"ok":true,"event":"accepted"}')

static func validate_command(payload: Dictionary) -> String:
	match payload.get("action", ""):
		"expression", "costume":
			var index: Variant = payload.get("index")
			if not (index is float or index is int) or not is_finite(float(index)) or index != int(index) or index < 0 or index > 31:
				return "Expected zero-based index from 0 to 31"
		"mute", "clips":
			if not payload.get("enabled") is bool:
				return "Expected enabled boolean"
		"blink", "reset":
			pass
		_:
			return "Unknown action"
	return ""

func _exit_tree() -> void:
	stop()

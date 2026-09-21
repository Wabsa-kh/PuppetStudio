extends Node

const Detector = preload("res://core/talking_detector.gd")
var detector = Detector.new()
var db := -96.0
var active := false
var available := false
var device_name := "Default"
var capture: AudioEffectCapture
var player: AudioStreamPlayer
var bus_index := -1
var stale_seconds := 0.0
var dropped_samples := 0
var device_poll := 0.0
var last_error := ""
signal devices_changed

func _ready() -> void:
	AudioServer.add_bus()
	bus_index = AudioServer.bus_count - 1
	AudioServer.set_bus_name(bus_index, "PuppetCapture")
	capture = AudioEffectCapture.new()
	capture.buffer_length = 0.1
	AudioServer.add_bus_effect(bus_index, capture)
	# Capture processes before the bus output is muted: no microphone feedback.
	AudioServer.set_bus_mute(bus_index, true)
	player = AudioStreamPlayer.new()
	player.stream = AudioStreamMicrophone.new()
	player.bus = "PuppetCapture"
	add_child(player)

func start(device: String = "Default") -> void:
	last_error = ""
	var devices := AudioServer.get_input_device_list()
	if devices.is_empty() or (devices.size() == 1 and devices[0] == "Default"):
		stop()
		last_error = "No microphone detected · connect a device and retry"
		return
	device_name = device
	AudioServer.input_device = device
	detector.reset()
	capture.clear_buffer()
	player.play()
	active = true
	stale_seconds = 0.0

func stop() -> void:
	active = false
	available = false
	db = -96.0
	player.stop()
	capture.clear_buffer()
	detector.reset()

func _process(delta: float) -> void:
	device_poll += delta
	if device_poll >= 2.0:
		device_poll = 0.0
		devices_changed.emit()
		if active and device_name != "Default" and not AudioServer.get_input_device_list().has(device_name):
			stop()
	if not active:
		return
	stale_seconds += delta
	var sample_rate := AudioServer.get_mix_rate()
	var count := maxi(1, int(sample_rate * 0.01))
	var blocks := 0
	while capture.can_get_buffer(count) and blocks < 12:
		var samples := capture.get_buffer(count)
		db = Detector.rms_db(samples)
		detector.update(db, float(count) / sample_rate)
		stale_seconds = 0.0
		available = true
		blocks += 1
	dropped_samples = capture.get_discarded_frames()
	if stale_seconds > 0.3:
		available = false
		db = -96.0
		detector.reset()

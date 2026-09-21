extends RefCounted

var threshold_db := -38.0
var hysteresis_db := 6.0
var attack_seconds := 0.025
var hold_seconds := 0.12
var release_seconds := 0.08
var talking := false
var above_time := 0.0
var below_time := 0.0

func reset() -> void:
	talking = false
	above_time = 0.0
	below_time = 0.0

func update(db: float, seconds: float) -> bool:
	if not is_finite(db) or seconds < 0.0:
		reset()
		return false
	if talking:
		if db < threshold_db - hysteresis_db:
			below_time += seconds
			if below_time >= hold_seconds + release_seconds:
				reset()
		else:
			below_time = 0.0
	else:
		if db >= threshold_db:
			above_time += seconds
			if above_time >= attack_seconds:
				talking = true
				below_time = 0.0
		else:
			above_time = 0.0
	return talking

static func rms_db(samples: PackedVector2Array) -> float:
	if samples.is_empty():
		return -96.0
	var energy := 0.0
	for sample in samples:
		energy += (sample.x * sample.x + sample.y * sample.y) * 0.5
	return maxf(-96.0, 20.0 * log(maxf(sqrt(energy / samples.size()), 0.00001585)) / log(10.0))

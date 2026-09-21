extends RefCounted

# Editing selection, latched expression, and temporary reactions are separate.
var base := 0
var held: Array[Dictionary] = []
var timed := -1
var remaining := 0.0

func reset(index := 0) -> void:
	base = index
	held.clear()
	timed = -1
	remaining = 0.0

func activate(index: int, mode: int, pressed: bool, duration: float = 2.0, source := "keyboard") -> void:
	if mode == 1:
		for entry in held.duplicate():
			if entry.source == source and entry.index == index:
				held.erase(entry)
		if pressed:
			held.append({"source": source, "index": index})
	elif pressed:
		if mode == 2:
			base = 0 if base == index else index
		elif mode == 3:
			timed = index
			remaining = duration
		else:
			base = index

func release_source(source: String) -> void:
	for entry in held.duplicate():
		if entry.source == source:
			held.erase(entry)

func update(delta: float, count: int) -> int:
	remaining = maxf(0, remaining - delta)
	if remaining <= 0:
		timed = -1
	var result := base
	if timed >= 0:
		result = timed
	if not held.is_empty():
		result = int(held.back().index)
	return clampi(result, 0, maxi(0, count - 1))

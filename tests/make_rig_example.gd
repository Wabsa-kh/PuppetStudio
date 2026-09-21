extends SceneTree

const Document = preload("res://core/document.gd")
var document = Document.new()

func part(name: String, svg: String, width := 256, height := 256) -> Dictionary:
	var image := Image.new()
	image.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">%s</svg>' % [width, height, width, height, svg])
	var layer: Dictionary = document.new_layer(name)
	layer.image = document.add_image(image)
	document.data.layers.append(layer)
	return layer

func _initialize() -> void:
	document.fresh()
	document.data.name = "Mochi · layered rig"
	document.data.expressions = [{"name": "Neutral", "idle": "", "talk": "", "blink": "", "talk_blink": ""}]
	var body := part("Body · breathing", '<path d="M42 250Q28 57 86 25H174Q226 60 215 250Z" fill="#829994" stroke="#394b50" stroke-width="6"/><path d="M70 168V249M186 168V249" stroke="#536f70" stroke-width="5"/>')
	body.y = 105.0
	body.float_y = 3.0
	body.sway_speed_y = 1.5
	var head := part("Head", '<path d="M22 65Q27 16 128 16Q228 16 234 65L244 155Q243 236 128 240Q11 236 12 155Z" fill="#e8d9bd" stroke="#555051" stroke-width="6"/><path d="M100 18L113 54L128 18L144 50L156 18" fill="#b6a383"/><ellipse cx="55" cy="167" rx="23" ry="11" fill="#dea292"/><ellipse cx="201" cy="167" rx="23" ry="11" fill="#dea292"/><path d="M118 150Q128 142 138 150L128 159Z" fill="#9c726c"/>')
	head.parent = body.id
	head.y = -150.0
	head.spring = true
	head.spring_frequency = 3.0
	head.sway = 3.0
	head.rotation_sway = 2.0
	var left := part("Left ear · spring", '<path d="M14 9Q72 14 106 110L24 112Z" fill="#e8d9bd" stroke="#555051" stroke-width="6" stroke-linejoin="round"/><path d="M34 38L79 92L39 97Z" fill="#c99e90"/>', 120, 120)
	left.parent = head.id
	left.x = -76.0
	left.y = -48.0
	left.pivot_y = 50.0
	left.spring = true
	left.spring_frequency = 2.5
	left.damping = 0.4
	left.rotation_drag = 0.7
	left.rotation_min = -18.0
	left.rotation_max = 18.0
	var right: Dictionary = left.duplicate(true)
	right.id = document.new_layer("").id
	right.name = "Right ear · spring"
	right.x = 76.0
	right.flip_x = true
	document.data.layers.append(right)
	var eyes := part("Eyes · open", '<ellipse cx="77" cy="125" rx="9" ry="18" fill="#3a3d49"/><ellipse cx="179" cy="125" rx="9" ry="18" fill="#3a3d49"/><circle cx="75" cy="118" r="3" fill="#fff"/><circle cx="177" cy="118" r="3" fill="#fff"/>')
	eyes.parent = head.id
	eyes.blink_rule = 2
	var blink := part("Eyes · blinking", '<path d="M64 129Q77 116 90 129M166 129Q179 116 192 129" fill="none" stroke="#3a3d49" stroke-width="6" stroke-linecap="round"/>')
	blink.parent = head.id
	blink.blink_rule = 1
	var closed := part("Mouth · silent", '<path d="M105 172Q116 189 128 172Q140 189 151 172" fill="none" stroke="#555051" stroke-width="5" stroke-linecap="round"/>')
	closed.parent = head.id
	closed.talk_rule = 2
	var talk := part("Mouth · talking", '<ellipse cx="128" cy="180" rx="19" ry="23" fill="#634751" stroke="#555051" stroke-width="4"/><ellipse cx="128" cy="191" rx="12" ry="8" fill="#d9919c"/>')
	talk.parent = head.id
	talk.talk_rule = 1
	var scarf := part("Scarf", '<path d="M30 20Q128 55 225 20L215 58Q128 86 40 58Z" fill="#466b81" stroke="#344b5e" stroke-width="5"/><path d="M160 65H197L211 135L174 130Z" fill="#466b81" stroke="#344b5e" stroke-width="5"/><path d="M181 116L204 119" stroke="#93adb6" stroke-width="4"/>', 256, 150)
	scarf.parent = body.id
	scarf.y = -32.0
	scarf.spring = true
	scarf.damping = 0.55
	# Ear artwork is behind the head, even though it inherits from the head.
	document.data.layers = [body, left, right, head, eyes, blink, closed, talk, scarf]
	var without: Dictionary = {}
	for layer in document.data.layers: without[layer.id] = layer.id != scarf.id
	document.data.costumes = [{"name": "Without scarf", "layers": without}]
	DirAccess.make_dir_recursive_absolute("res://samples")
	var error: String = document.save_to("res://samples/Rigged-Mochi.puppet")
	print("RIG_SAMPLE: " + ("saved" if error.is_empty() else error))
	quit(0 if error.is_empty() else 1)

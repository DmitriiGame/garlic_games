extends Control
## Палочные сценки. scene_name выбирается событием, mood — исходом.

var scene_name: String = "door"
var mood: String = "idle"
var time: float = 0.0

const PAPER := Color("f4ecdf")
const AMBER := Color("f0a05a")
const BLOOD := Color("e07a6a")
const MOSS := Color("b6c96a")
const INK := Color("14110e")
const LINE := Color("3a332c")


func _process(delta: float) -> void:
	time += delta
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color("171410"))
	if size.x < 8.0 or size.y < 8.0:
		return
	var floor_y := size.y * 0.84
	draw_line(Vector2(28, floor_y), Vector2(size.x - 28, floor_y), LINE, 4.0, true)
	match scene_name:
		"door":
			_door(Vector2(size.x * 0.66, floor_y), false)
			_person(Vector2(size.x * 0.32, floor_y), {})
			_knocks(Vector2(size.x * 0.66, floor_y))
		"open":
			_door(Vector2(size.x * 0.58, floor_y), true)
			_person(Vector2(size.x * 0.28, floor_y), {})
			_person(Vector2(size.x * 0.78, floor_y), {"zombie": mood == "bad", "sc": 0.92})
		"basement":
			_stairs(floor_y)
			_person(Vector2(size.x * 0.38, floor_y), {"hold": "lamp"})
		"window":
			_window(floor_y)
			_person(Vector2(size.x * 0.3, floor_y), {})
		"stranger":
			_person(Vector2(size.x * 0.3, floor_y), {})
			_person(Vector2(size.x * 0.68, floor_y), {"hold": "can", "lean": 0.05})
		"radio":
			_person(Vector2(size.x * 0.34, floor_y), {})
			_radio(Vector2(size.x * 0.68, floor_y - 36))
		"dog":
			_person(Vector2(size.x * 0.34, floor_y), {})
			_dog(Vector2(size.x * 0.66, floor_y))
		"street":
			_skyline(floor_y)
			_person(Vector2(size.x * 0.42, floor_y), {})
		"mirror":
			_mirror(floor_y)
			_person(Vector2(size.x * 0.34, floor_y), {})
		"kid":
			_person(Vector2(size.x * 0.36, floor_y), {})
			_person(Vector2(size.x * 0.66, floor_y), {"sc": 0.62, "wave": true})
		"horde":
			_person(Vector2(size.x * 0.22, floor_y), {"sc": 0.85})
			for i in 4:
				_person(Vector2(size.x * (0.48 + i * 0.1), floor_y), {"zombie": true, "sc": 0.78, "lean": 0.2})
		"gun":
			_person(Vector2(size.x * 0.36, floor_y), {"hold": "gun"})
			_case(Vector2(size.x * 0.7, floor_y))
		"letter":
			_door(Vector2(size.x * 0.64, floor_y), false)
			_letter(Vector2(size.x * 0.42, floor_y - 8))
			_person(Vector2(size.x * 0.24, floor_y), {})
		"food":
			_person(Vector2(size.x * 0.36, floor_y), {})
			_can(Vector2(size.x * 0.66, floor_y - 28), 1.4)
		"cult":
			_person(Vector2(size.x * 0.24, floor_y), {})
			for i in 3:
				_person(Vector2(size.x * (0.48 + i * 0.14), floor_y), {"sc": 0.86, "wave": true, "zombie": mood == "bad"})
		"soldier":
			_door(Vector2(size.x * 0.62, floor_y), false)
			_person(Vector2(size.x * 0.28, floor_y), {})
			_person(Vector2(size.x * 0.8, floor_y), {"hat": true, "sc": 0.95})
		"death":
			_door(Vector2(size.x * 0.62, floor_y), true)
			_person(Vector2(size.x * 0.34, floor_y), {"fallen": true, "xeyes": true})
			_person(Vector2(size.x * 0.78, floor_y), {"zombie": true, "sc": 1.05})
		"win":
			_sun(Vector2(size.x * 0.78, size.y * 0.28))
			_door(Vector2(size.x * 0.3, floor_y), true)
			if _flag("has_dog"):
				_dog(Vector2(size.x * 0.5, floor_y))
			_person(Vector2(size.x * 0.68, floor_y), {})
			if _flag("kid_saved"):
				_person(Vector2(size.x * 0.86, floor_y), {"sc": 0.62, "wave": true})
		_:
			_person(Vector2(size.x * 0.48, floor_y), {})
	if mood == "bad":
		draw_rect(rect, Color(0.75, 0.12, 0.1, 0.16))
	elif mood == "good":
		draw_rect(rect, Color(0.55, 0.7, 0.3, 0.08))


func _flag(flag_name: String) -> bool:
	var game := get_node_or_null("/root/Game")
	if game == null:
		return false
	return bool(game.flags.get(flag_name, false))


func _person(feet: Vector2, opts: Dictionary) -> void:
	var scale: float = float(opts.get("sc", 1.0))
	var lean: float = float(opts.get("lean", 0.0))
	var col := PAPER
	if bool(opts.get("zombie", false)):
		col = BLOOD
		lean += 0.22
	if mood == "bad" and not bool(opts.get("zombie", false)) and scene_name != "win":
		col = Color("f2d2c4")
	var bob := sin(time * 2.2 + feet.x * 0.01) * 3.0 * scale
	if bool(opts.get("fallen", false)):
		var head := feet + Vector2(-58 * scale, -28 * scale)
		var shoulder := head + Vector2(22 * scale, 8 * scale)
		var hip := shoulder + Vector2(48 * scale, 6 * scale)
		var width := 6.0 * scale
		draw_arc(head, 14 * scale, 0, TAU, 20, col, width, true)
		_eyes(head, scale, true, false)
		draw_line(shoulder, hip, col, width, true)
		draw_line(shoulder, shoulder + Vector2(6 * scale, -26 * scale), col, width, true)
		draw_line(hip, hip + Vector2(18 * scale, 16 * scale), col, width, true)
		draw_line(hip, hip + Vector2(34 * scale, -4 * scale), col, width, true)
		return
	var hip := feet + Vector2(lean * 18.0, -68.0 * scale + bob)
	var shoulder := hip + Vector2(lean * 26.0, -54.0 * scale)
	var head := shoulder + Vector2(lean * 8.0, -26.0 * scale)
	var width := 6.0 * scale
	draw_line(hip, feet + Vector2(-16 * scale, 0), col, width, true)
	draw_line(hip, feet + Vector2(18 * scale, 0), col, width, true)
	draw_line(hip, shoulder, col, width, true)
	var wave := sin(time * 4.0) * (14.0 if bool(opts.get("wave", false)) else 2.0)
	draw_line(shoulder, shoulder + Vector2(-36 * scale, 18 * scale + wave), col, width, true)
	var hold := str(opts.get("hold", ""))
	var hand := shoulder + Vector2(38 * scale, 22 * scale)
	draw_line(shoulder, hand, col, width, true)
	draw_arc(head, 16 * scale, 0, TAU, 24, col, width, true)
	_eyes(head, scale, bool(opts.get("xeyes", false)) or (mood == "bad" and scene_name == "death"), bool(opts.get("zombie", false)))
	if bool(opts.get("hat", false)):
		draw_rect(Rect2(head + Vector2(-18 * scale, -22 * scale), Vector2(36 * scale, 8 * scale)), AMBER)
	if hold == "can":
		_can(hand + Vector2(6, 8), 0.7)
	elif hold == "lamp":
		draw_line(hand, hand + Vector2(10, 16), AMBER, 3, true)
		draw_circle(hand + Vector2(10, 24), 7, AMBER)
	elif hold == "gun":
		draw_line(hand, hand + Vector2(28, 4), PAPER, 4, true)
		draw_line(hand + Vector2(6, 4), hand + Vector2(6, 16), PAPER, 4, true)


func _eyes(head: Vector2, scale: float, cross: bool, zombie: bool) -> void:
	if cross:
		var d := 6.0 * scale
		draw_line(head + Vector2(-8, -4) * scale, head + Vector2(-8 + d, -4 + d), INK, 2.5, true)
		draw_line(head + Vector2(-8 + d, -4) * scale, head + Vector2(-8, -4 + d), INK, 2.5, true)
		draw_line(head + Vector2(2, -4) * scale, head + Vector2(2 + d, -4 + d), INK, 2.5, true)
		draw_line(head + Vector2(2 + d, -4) * scale, head + Vector2(2, -4 + d), INK, 2.5, true)
		return
	var col := INK if not zombie else Color("2a0c0c")
	var blink := 1.0 if sin(time * 0.7) > -0.97 else 0.2
	draw_circle(head + Vector2(-6 * scale, -2 * scale), 2.2 * scale * blink + 0.6, col)
	draw_circle(head + Vector2(6 * scale, -1 * scale), 2.2 * scale * blink + 0.6, col)


func _door(origin: Vector2, open: bool) -> void:
	var rect := Rect2(origin + Vector2(-46, -196), Vector2(96, 196))
	draw_rect(Rect2(rect.position + Vector2(-8, -8), rect.size + Vector2(16, 16)), Color("2a241f"))
	if open:
		draw_rect(rect, Color("0c0b0a"))
		var swung := Rect2(rect.position + Vector2(rect.size.x - 18, 8), Vector2(22, rect.size.y - 16))
		_stroke(swung, PAPER, 5)
	else:
		_stroke(rect, PAPER, 6)
		draw_arc(rect.position + Vector2(72, 96), 7, 0, TAU, 16, AMBER, 3, true)
		draw_circle(rect.position + Vector2(74, 128), 4, AMBER)
	draw_line(rect.position + Vector2(0, rect.size.y), rect.end, LINE, 3, true)


func _stroke(rect: Rect2, color: Color, width: float) -> void:
	draw_rect(rect, color, false, width)


func _knocks(origin: Vector2) -> void:
	var pulse: float = 0.45 + 0.55 * absf(sin(time * 6.0))
	var center := origin + Vector2(-58, -120)
	draw_arc(center, 18 + pulse * 10.0, -0.8, 0.8, 8, Color(AMBER.r, AMBER.g, AMBER.b, pulse), 3, true)
	draw_arc(center, 30 + pulse * 12.0, -0.7, 0.7, 8, Color(PAPER.r, PAPER.g, PAPER.b, pulse * 0.7), 2, true)


func _stairs(floor_y: float) -> void:
	var x := size.x * 0.62
	var y := floor_y
	for i in 5:
		var step := Rect2(Vector2(x + i * 18, y - (i + 1) * 28), Vector2(70, 10))
		_stroke(step, PAPER, 4)


func _window(floor_y: float) -> void:
	var rect := Rect2(Vector2(size.x * 0.58, floor_y - 210), Vector2(120, 150))
	_stroke(rect, PAPER, 6)
	draw_line(rect.position + Vector2(rect.size.x * 0.5, 0), rect.position + Vector2(rect.size.x * 0.5, rect.size.y), PAPER, 4, true)
	draw_line(rect.position + Vector2(0, rect.size.y * 0.5), rect.position + Vector2(rect.size.x, rect.size.y * 0.5), PAPER, 4, true)
	var eye := rect.position + Vector2(rect.size.x * 0.72, rect.size.y * 0.32)
	var blink := 0.5 + 0.5 * sin(time * 3.0)
	draw_circle(eye, 5, Color(BLOOD.r, BLOOD.g, BLOOD.b, 0.4 + blink * 0.6))
	draw_circle(eye + Vector2(16, 2), 5, Color(BLOOD.r, BLOOD.g, BLOOD.b, 0.4 + blink * 0.6))


func _radio(pos: Vector2) -> void:
	var rect := Rect2(pos + Vector2(-28, -24), Vector2(64, 44))
	_stroke(rect, PAPER, 4)
	draw_circle(rect.position + Vector2(18, 22), 8, AMBER)
	var reach := 16.0 + sin(time * 5.0) * 8.0
	draw_arc(rect.end + Vector2(-8, -rect.size.y), reach, -1.2, 1.2, 10, MOSS, 2, true)


func _dog(feet: Vector2) -> void:
	var wag := sin(time * 8.0) * 10.0
	var body := feet + Vector2(-6, -28)
	draw_line(body + Vector2(-28, 4), body + Vector2(22, -2), PAPER, 7, true)
	draw_arc(body + Vector2(30, -16), 13, 0, TAU, 18, PAPER, 5, true)
	draw_circle(body + Vector2(26, -20), 2.4, INK)
	draw_line(body + Vector2(34, -24), body + Vector2(42, -34), PAPER, 3, true)
	draw_line(body + Vector2(22, -8), body + Vector2(14, -36), PAPER, 3, true)
	draw_line(body + Vector2(-16, 2), feet + Vector2(-22, 0), PAPER, 4, true)
	draw_line(body + Vector2(-4, 2), feet + Vector2(2, 0), PAPER, 4, true)
	draw_line(body + Vector2(10, 0), feet + Vector2(16, 0), PAPER, 4, true)
	draw_line(body + Vector2(18, -2), feet + Vector2(28, 0), PAPER, 4, true)
	draw_line(body + Vector2(-28, 2), body + Vector2(-46, -8 + wag), AMBER, 4, true)


func _skyline(floor_y: float) -> void:
	var blocks := [40, 70, 28, 90, 50, 76]
	var x := 36.0
	for height in blocks:
		draw_rect(Rect2(Vector2(x, floor_y - height), Vector2(28, height)), Color("241f1b"))
		_stroke(Rect2(Vector2(x, floor_y - height), Vector2(28, height)), LINE, 3)
		x += 36


func _mirror(floor_y: float) -> void:
	var center := Vector2(size.x * 0.7, floor_y - 110)
	draw_arc(center, 54, 0, TAU, 32, PAPER, 6, true)
	draw_arc(center, 40, 0.4, PI - 0.4, 16, Color(BLOOD.r, BLOOD.g, BLOOD.b, 0.8), 3, true)
	draw_line(center + Vector2(-10, -8), center + Vector2(18, 22), BLOOD, 2, true)


func _case(feet: Vector2) -> void:
	var rect := Rect2(feet + Vector2(-30, -36), Vector2(60, 36))
	_stroke(rect, AMBER, 4)
	draw_line(rect.position + Vector2(8, 18), rect.position + Vector2(rect.size.x - 8, 18), AMBER, 3, true)


func _letter(pos: Vector2) -> void:
	var rect := Rect2(pos + Vector2(-22, -30), Vector2(44, 30))
	draw_rect(rect, PAPER)
	draw_line(rect.position, rect.position + Vector2(rect.size.x * 0.5, 16), INK, 2, true)
	draw_line(rect.position + Vector2(rect.size.x, 0), rect.position + Vector2(rect.size.x * 0.5, 16), INK, 2, true)


func _can(pos: Vector2, scale: float) -> void:
	var rect := Rect2(pos + Vector2(-12, -28) * scale, Vector2(24, 32) * scale)
	_stroke(rect, MOSS, 4)
	draw_line(rect.position + Vector2(0, 8 * scale), rect.position + Vector2(rect.size.x, 8 * scale), MOSS, 3, true)


func _sun(center: Vector2) -> void:
	draw_arc(center, 28, 0, TAU, 24, AMBER, 4, true)
	for i in 8:
		var angle := i * TAU / 8.0 + time * 0.3
		draw_line(center + Vector2(cos(angle), sin(angle)) * 36, center + Vector2(cos(angle), sin(angle)) * 52, AMBER, 3, true)

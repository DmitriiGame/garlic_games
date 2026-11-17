extends Control
## Двор из окна чердака. Даль — выше. Цвета краёв берутся из данных, остальное из темы.

signal tapped(index: int)

var mode := "aim"
var flight_k := 0.0
var target_distance := 0.0
var aim_distance := 0.0
var view_max := 80.0
var flash := 0.0
var guests: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func set_view(next_view: float) -> void:
	view_max = maxf(20.0, next_view)


func set_mode(next_mode: String) -> void:
	mode = next_mode
	queue_redraw()


func set_flight_k(k: float) -> void:
	flight_k = clampf(k, 0.0, 1.0)
	queue_redraw()


func start_round(distance: float, next_view: float, specs: Array) -> void:
	target_distance = distance
	view_max = maxf(next_view, distance + 5.0)
	flight_k = 0.0
	mode = "flight"
	guests.clear()
	for spec in specs:
		guests.append({
			"id": str(spec.get("id", "")),
			"shape": str(spec.get("shape", "blob")),
			"color": str(spec.get("color", "#888888")),
			"window": float(spec.get("window", 1.5)),
			"delay": float(spec.get("delay", 0.0)),
			"state": "approach",
			"approach": 0.0,
			"time_left": float(spec.get("window", 1.5)),
			"pop": 0.0,
			"flee": 0.0,
		})
	queue_redraw()


func begin_chase() -> void:
	mode = "catch"
	queue_redraw()


func skip_to_wait() -> void:
	for guest in guests:
		guest.state = "wait"
		guest.approach = 1.0
		guest.time_left = float(guest.window)
	mode = "catch"
	queue_redraw()


func can_catch(index: int) -> bool:
	if index < 0 or index >= guests.size():
		return false
	var guest: Dictionary = guests[index]
	var state := str(guest.get("state", ""))
	if state == "wait":
		return true
	return state == "approach" and float(guest.get("approach", 0)) >= 0.8


func guest_id(index: int) -> String:
	if index < 0 or index >= guests.size():
		return ""
	return str(guests[index].get("id", ""))


func mark_caught(index: int) -> void:
	if index < 0 or index >= guests.size():
		return
	guests[index].state = "caught"
	guests[index].pop = 0.0
	queue_redraw()


func all_settled() -> bool:
	if guests.is_empty():
		return true
	for guest in guests:
		if str(guest.get("state", "")) != "gone":
			return false
	return true


func advance(delta: float) -> void:
	if flash > 0.0:
		flash = maxf(0.0, flash - delta)
	for guest in guests:
		var state := str(guest.get("state", ""))
		if state == "approach":
			var delay := float(guest.get("delay", 0))
			if delay > 0.0:
				guest.delay = maxf(0.0, delay - delta)
			else:
				guest.approach = minf(1.0, float(guest.get("approach", 0)) + delta / 0.5)
				if float(guest.approach) >= 1.0:
					guest.state = "wait"
					guest.time_left = float(guest.window)
		elif state == "wait":
			guest.time_left = float(guest.time_left) - delta
			if float(guest.time_left) <= 0.0:
				guest.state = "flee"
				guest.flee = 0.0
		elif state == "caught":
			guest.pop = float(guest.pop) + delta / 0.22
			if float(guest.pop) >= 1.0:
				guest.state = "gone"
		elif state == "flee":
			guest.flee = float(guest.flee) + delta / 0.35
			if float(guest.flee) >= 1.0:
				guest.state = "gone"
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if mode != "catch":
		return
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed:
			var index := _hit(mouse.position)
			if index >= 0:
				tapped.emit(index)
				accept_event()


func _draw() -> void:
	if size.y < 20.0 or size.x < 20.0:
		return
	draw_rect(Rect2(Vector2.ZERO, size), ThrowTheme.SKY)
	draw_circle(Vector2(size.x * 0.78, 48), 26, ThrowTheme.CLOUD)
	draw_circle(Vector2(size.x * 0.18, 70), 18, ThrowTheme.CLOUD)
	_draw_bands()
	_draw_marker()
	_draw_grandma()
	_draw_slipper(_slipper_pos(), 1.0)
	_draw_guests()
	_draw_frame()
	if flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(ThrowTheme.ACCENT.r, ThrowTheme.ACCENT.g, ThrowTheme.ACCENT.b, 0.18 * flash))


func _draw_bands() -> void:
	var view := maxf(view_max, 1.0)
	for index in Content.biomes.size():
		var biome: Dictionary = Content.biomes[index]
		var start := float(biome.get("unlock_distance", 0))
		var finish := view
		if index + 1 < Content.biomes.size():
			finish = float(Content.biomes[index + 1].get("unlock_distance", 0))
		finish = minf(finish, view)
		if finish <= start:
			continue
		var top := _y(finish)
		var bottom := _y(start)
		var biome_id := str(biome.get("id", ""))
		var open := Game.unlocked.has(biome_id)
		var color := ThrowTheme.color_or(str(biome.get("ground", "")), ThrowTheme.GRASS)
		if not open:
			color = color.darkened(0.45)
		draw_rect(Rect2(Vector2(0, top), Vector2(size.x, maxf(1.0, bottom - top) + 1.0)), color)
		if bottom - top > 32.0:
			var title := str(biome.get("name", ""))
			if not open:
				title = "%s · %d м" % [title, int(round(start))]
			var font_color := ThrowTheme.INK if open else ThrowTheme.MUTED
			draw_string(ThrowFonts.BODY, Vector2(18, top + 24), title, HORIZONTAL_ALIGNMENT_LEFT, size.x - 36, 18, font_color)


func _draw_marker() -> void:
	var distance := aim_distance if mode == "aim" else target_distance
	var y := _y(distance)
	draw_line(Vector2(14, y), Vector2(size.x - 14, y), ThrowTheme.ACCENT, 3.0, true)


func _draw_grandma() -> void:
	var feet := Vector2(size.x * 0.28, size.y - 58)
	draw_rect(Rect2(Vector2(0, size.y - 58), Vector2(size.x, 58)), ThrowTheme.SILL)
	draw_colored_polygon(PackedVector2Array([
		feet + Vector2(-28, -8), feet + Vector2(28, -4), feet + Vector2(18, -52), feet + Vector2(-18, -56),
	]), ThrowTheme.DRESS)
	draw_circle(feet + Vector2(0, -70), 16, ThrowTheme.SKIN)
	draw_colored_polygon(PackedVector2Array([
		feet + Vector2(-20, -78), feet + Vector2(18, -86), feet + Vector2(22, -64), feet + Vector2(-16, -62),
	]), ThrowTheme.SCARF)
	draw_rect(Rect2(feet + Vector2(10, -48), Vector2(34, 8)), ThrowTheme.DRESS)


func _grandma_hand() -> Vector2:
	return Vector2(size.x * 0.28 + 46, size.y - 102)


func _slipper_pos() -> Vector2:
	var hand := _grandma_hand()
	var land := Vector2(size.x * 0.62, _y(target_distance))
	if mode == "aim":
		return hand
	var k := _ease(flight_k if mode == "flight" else 1.0)
	var arc := sin(k * PI) * 64.0
	return hand.lerp(land, k) + Vector2(0, -arc)


func _draw_slipper(at: Vector2, draw_scale: float) -> void:
	var item: Dictionary = Content.item_by_id.get(Game.equipped, {})
	var color := ThrowTheme.color_or(str(item.get("color", "")), ThrowTheme.SLIPPER)
	CritterDraw._poly(self, at, draw_scale, PackedVector2Array([
		Vector2(-8, 8), Vector2(34, 2), Vector2(46, 12), Vector2(30, 22), Vector2(-4, 18), Vector2(-14, 10),
	]), color)
	draw_circle(at + Vector2(2, 10) * draw_scale, 5.0 * draw_scale, color.darkened(0.28))


func _draw_guests() -> void:
	if mode == "aim" or mode == "flight":
		return
	for index in guests.size():
		var guest: Dictionary = guests[index]
		if str(guest.get("state", "")) == "gone":
			continue
		var spot := _guest_spot(index)
		var side := Vector2(-30.0 if index % 2 == 0 else size.x + 30.0, spot.y)
		var pos := side.lerp(spot, float(guest.get("approach", 0)))
		if str(guest.state) == "flee":
			pos = spot.lerp(side, float(guest.get("flee", 0)))
		var alpha := 1.0
		var draw_scale := 1.05
		if str(guest.state) == "caught":
			var pop := float(guest.get("pop", 0))
			draw_scale = 1.05 + pop * 0.45
			alpha = 1.0 - pop
		if can_catch(index):
			draw_circle(pos, 40, Color(ThrowTheme.PAPER.r, ThrowTheme.PAPER.g, ThrowTheme.PAPER.b, 0.28))
			var window := maxf(0.1, float(guest.window))
			var frac := clampf(float(guest.time_left) / window, 0.0, 1.0) if str(guest.state) == "wait" else 1.0
			draw_arc(pos, 40, -PI * 0.5, -PI * 0.5 + TAU * frac, 28, ThrowTheme.INK, 3.0, true)
		var tint := ThrowTheme.color_or(str(guest.get("color", "")), ThrowTheme.ACCENT)
		CritterDraw.paint(self, pos, str(guest.get("shape", "blob")), tint, draw_scale, true, alpha)


func _draw_frame() -> void:
	draw_rect(Rect2(0, 0, size.x, 10), ThrowTheme.WOOD)
	draw_rect(Rect2(0, size.y - 10, size.x, 10), ThrowTheme.WOOD)
	draw_rect(Rect2(0, 0, 10, size.y), ThrowTheme.WOOD)
	draw_rect(Rect2(size.x - 10, 0, 10, size.y), ThrowTheme.WOOD)


func _guest_spot(index: int) -> Vector2:
	var count := guests.size()
	var land := Vector2(size.x * 0.62, _y(target_distance))
	var cols := mini(count, 3)
	var row := int(index / 3)
	var col := index % 3
	var gap := 118.0
	var x := land.x + (float(col) - float(cols - 1) * 0.5) * gap
	var y := land.y - 86.0 - float(row) * 112.0
	return Vector2(clampf(x, 64, size.x - 64), clampf(y, 78, size.y - 96))


func _hit(point: Vector2) -> int:
	for index in range(guests.size() - 1, -1, -1):
		if str(guests[index].get("state", "")) == "gone":
			continue
		if not can_catch(index):
			continue
		if point.distance_to(_guest_spot(index)) <= 46.0:
			return index
	return -1


func _y(distance: float) -> float:
	var span := maxf(10.0, size.y - 150.0)
	var t := clampf(distance / maxf(view_max, 1.0), 0.0, 1.0)
	return size.y - 78.0 - t * span


func _ease(k: float) -> float:
	return k * k * (3.0 - 2.0 * k)

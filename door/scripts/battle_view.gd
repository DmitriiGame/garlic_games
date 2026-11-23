extends Control
## Экран боя: карточка истории, полоски, заклинания и поле 6×5.
## Жест ловится целиком (нажатие и отпускание), а не кнопкой фишки:
## на вебе свайп отпускается уже на другой клетке, и TextureButton.pressed не приходит.

const Palette := preload("res://scripts/door_theme.gd")

signal finished(won: bool)

var header: Label
var food_label: Label
var ammo_label: Label
var story: Label
var mob_card: Control
var animating := false
var photo: TextureRect
var card_name: Label
var ink_mat: ShaderMaterial
var hero_fill: ColorRect
var hero_label: Label
var shield_label: Label
var enemy_name: Label
var enemy_fill: ColorRect
var enemy_portrait: TextureRect
var intent: Label
var energy_segs: Array = []
var energy_label: Label
var footer: Label
var grid: GridContainer
var cell_panels: Array = []
var cell_icons: Array = []
var spell_buttons: Dictionary = {}
var leave: Button
var selected: Vector2i = Vector2i(-1, -1)
var pressing := false
var drag_from := Vector2i(-1, -1)
var last_gesture_ms := 0
var gesture_pointer := -2
var gesture_from := Vector2i(-1, -1)
var gesture_origin := Vector2.ZERO
var gesture_fired := false
var cell_span := 72.0
var last_touch_ms := 0
var last_kind := ""
var display: Font
var body: Font


func setup(display_font: Font, body_font: Font) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	display = display_font
	body = body_font
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(box)

	box.add_child(_top_bar())
	mob_card = _story_card()
	box.add_child(mob_card)
	box.add_child(_text_box())
	box.add_child(_spell_row())
	box.add_child(_enemy_row())
	box.add_child(_board_tray())
	box.add_child(_reward_bar())
	leave = Button.new()
	leave.text = "Дальше"
	leave.visible = false
	leave.custom_minimum_size = Vector2(0, 72)
	leave.add_theme_font_override("font", display)
	leave.add_theme_font_size_override("font_size", 32)
	_paint_button(leave, Palette.PANEL, Palette.INK)
	leave.pressed.connect(_leave)
	box.add_child(leave)


func _story_card() -> Control:
	var card := Panel.new()
	card.custom_minimum_size = Vector2(0, 250)
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	card.add_theme_stylebox_override("panel", _frame(Color("14110f"), Palette.RUST, 4))
	card.clip_contents = true
	var inner := VBoxContainer.new()
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = 8
	inner.offset_top = 8
	inner.offset_right = -8
	inner.offset_bottom = -8
	inner.add_theme_constant_override("separation", 6)
	card.add_child(inner)
	var art := Control.new()
	art.custom_minimum_size = Vector2(0, 210)
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art.clip_contents = false
	inner.add_child(art)
	photo = TextureRect.new()
	photo.set_anchors_preset(Control.PRESET_FULL_RECT)
	photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ink_mat = ShaderMaterial.new()
	ink_mat.shader = preload("res://shaders/ink_photo.gdshader")
	ink_mat.set_shader_parameter("ink", Palette.INK)
	ink_mat.set_shader_parameter("marker", Palette.MARKER)
	art.add_child(photo)
	card_name = _line("", 28, display)
	card_name.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	card_name.offset_left = 12
	card_name.offset_top = -44
	card_name.offset_right = 420
	card_name.offset_bottom = -8
	card_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.add_child(card_name)
	var stamp := _line("БОЙ", 36, display)
	stamp.add_theme_color_override("font_color", Palette.MARKER)
	stamp.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	stamp.offset_left = -210
	stamp.offset_top = 6
	stamp.offset_right = -36
	stamp.offset_bottom = 56
	stamp.rotation_degrees = -8
	stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.add_child(stamp)
	return card


func _top_bar() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	header = _single_line("", 20)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	header.clip_text = true
	row.add_child(header)
	row.add_child(_icon("res://art/ui/stat_health.png"))
	hero_label = _single_line("40", 22)
	row.add_child(hero_label)
	row.add_child(_icon("res://art/ui/stat_food.png"))
	food_label = _single_line("0", 22)
	row.add_child(food_label)
	row.add_child(_icon("res://art/ui/stat_ammo.png"))
	ammo_label = _single_line("0", 22)
	row.add_child(ammo_label)
	return row


func _text_box() -> Control:
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", _frame(Color("14110f"), Palette.RUST, 3))
	panel.custom_minimum_size = Vector2(0, 72)
	story = _line("", 22, body)
	story.max_lines_visible = 2
	story.set_anchors_preset(Control.PRESET_FULL_RECT)
	story.offset_left = 12
	story.offset_top = 8
	story.offset_right = -12
	story.offset_bottom = -8
	panel.add_child(story)
	return panel


func _reward_bar() -> Control:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(0, 64)
	panel.add_theme_stylebox_override("panel", _frame(Color("14110f"), Palette.RUST, 3))
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 10
	row.offset_top = 8
	row.offset_right = -10
	row.offset_bottom = -8
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(_icon("res://art/ui/door.png"))
	footer = _line("", 20, display)
	footer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(footer)
	panel.add_child(row)
	return panel


func _icon(path: String) -> TextureRect:
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(28, 28)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(path):
		icon.texture = load(path)
	return icon


func _hero_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	hero_label = _line("вы", 22, display)
	hero_label.custom_minimum_size = Vector2(64, 0)
	row.add_child(hero_label)
	var bar := _bar()
	hero_fill = bar[1]
	hero_fill.color = Palette.MARKER
	row.add_child(bar[0])
	shield_label = _line("щит 0", 20, body)
	shield_label.custom_minimum_size = Vector2(90, 0)
	row.add_child(shield_label)
	return row


func _enemy_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	enemy_portrait = TextureRect.new()
	enemy_portrait.custom_minimum_size = Vector2(64, 64)
	enemy_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	enemy_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	enemy_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(enemy_portrait)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 4)
	enemy_name = _line("Враг: 0/0", 22, display)
	col.add_child(enemy_name)
	intent = _line("", 18, body)
	col.add_child(intent)
	var bar := _bar()
	enemy_fill = bar[1]
	enemy_fill.color = Palette.MARKER
	col.add_child(bar[0])
	row.add_child(col)
	return row


func _spell_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var spells := [
		["shot", "Выстрел", "2", "res://art/ui/spell_shot.png"],
		["grenade", "Граната", "4", "res://art/ui/spell_grenade.png"],
		["kit", "Аптечка", "3", "res://art/ui/spell_kit.png"],
	]
	for item in spells:
		var button := Button.new()
		button.text = ""
		button.custom_minimum_size = Vector2(0, 78)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var fills := {
			"shot": Color("3a2420"),
			"grenade": Color("3a3018"),
			"kit": Color("1e3324"),
		}
		var borders := {
			"shot": Palette.MARKER,
			"grenade": Color("e2b84a"),
			"kit": Color("7dba8a"),
		}
		_paint_button(button, fills[item[0]], borders[item[0]])
		var inner := HBoxContainer.new()
		inner.set_anchors_preset(Control.PRESET_FULL_RECT)
		inner.offset_left = 8
		inner.offset_top = 6
		inner.offset_right = -8
		inner.offset_bottom = -6
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.alignment = BoxContainer.ALIGNMENT_CENTER
		button.add_child(inner)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(40, 40)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if ResourceLoader.exists(item[3]):
			icon.texture = load(item[3])
		inner.add_child(icon)
		var words := VBoxContainer.new()
		words.mouse_filter = Control.MOUSE_FILTER_IGNORE
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var title := _line(item[1], 20, display)
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cost := _line(item[2], 22, display)
		cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cost.add_theme_color_override("font_color", Color("e2b84a"))
		words.add_child(title)
		words.add_child(cost)
		inner.add_child(words)
		var spell_id := str(item[0])
		button.pressed.connect(func() -> void: _cast(spell_id))
		row.add_child(button)
		spell_buttons[spell_id] = button
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 6)
	wrap.add_child(row)
	var energy := HBoxContainer.new()
	energy.add_theme_constant_override("separation", 4)
	energy.add_child(_icon("res://art/ui/lightning.png"))
	for _i in 10:
		var seg := ColorRect.new()
		seg.custom_minimum_size = Vector2(0, 22)
		seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		seg.color = Color("3a2422")
		seg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		energy.add_child(seg)
		energy_segs.append(seg)
	energy_label = _single_line("0/10", 20)
	energy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	energy.add_child(energy_label)
	wrap.add_child(energy)
	return wrap


func _board_tray() -> Control:
	var tray := Panel.new()
	tray.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tray.size_flags_stretch_ratio = 1.4
	tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tray.add_theme_stylebox_override("panel", _frame(Color("100e0c"), Palette.RUST, 4))
	var inset := MarginContainer.new()
	inset.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		inset.add_theme_constant_override("margin_" + side, 10)
	tray.add_child(inset)
	grid = GridContainer.new()
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.columns = 6
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	inset.add_child(grid)
	for i in 30:
		var panel := Panel.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		panel.custom_minimum_size = Vector2(0, 56)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_theme_stylebox_override("panel", _cell_style(false, false))
		var icon := TextureRect.new()
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.offset_left = 4
		icon.offset_top = 4
		icon.offset_right = -4
		icon.offset_bottom = -4
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(icon)
		grid.add_child(panel)
		cell_panels.append(panel)
		cell_icons.append(icon)
	return tray


func refresh() -> void:
	var fight = Game.battle
	if fight == null:
		return
	header.text = Game.header_text()
	food_label.text = str(int(Game.stats.get("food", 0)))
	ammo_label.text = str(int(Game.stats.get("ammo", 0)))
	story.text = Game.battle_blurb()
	_show_enemy_card(fight)
	var shield := int(fight.shield)
	hero_label.text = "%d+%d" % [int(fight.hp), shield] if shield > 0 else "%d" % int(fight.hp)
	var enemy_max := maxi(1, int(fight.enemy.get("max_hp", 1)))
	var extra := ""
	if int(fight.minion_hp) > 0:
		extra = " +%d" % int(fight.minion_hp)
	enemy_name.text = "Враг: %d/%d%s" % [int(fight.enemy["hp"]), enemy_max, extra]
	_set_fill(enemy_fill, float(int(fight.enemy["hp"])) / float(enemy_max))
	var portrait := "pigeon" if str(fight.enemy.get("id", "")) == "pigeon" else "%s_%s" % [str(fight.enemy.get("id", "")), str(fight.enemy.get("subtype", "a"))]
	enemy_portrait.texture = _portrait(portrait)
	intent.text = "задумано: %s" % str(fight.enemy.get("intent", ""))
	var energy := int(fight.energy)
	energy_label.text = "%d/10" % energy
	for i in energy_segs.size():
		var seg: ColorRect = energy_segs[i]
		seg.color = Palette.MARKER if i < energy else Color("3a2422")
	footer.text = Game.battle_reward_text()
	if intent != null:
		intent.text = "%s · %s" % [str(fight.enemy.get("name", "")), str(fight.enemy.get("intent", ""))]
	leave.visible = fight.over
	leave.disabled = not fight.over
	leave.text = "Дальше" if fight.victory else "Это конец"
	for spell_id in spell_buttons.keys():
		var button: Button = spell_buttons[spell_id]
		button.disabled = fight.over or fight.turn != "player" or fight.swapped or fight.energy < fight._spell_cost(spell_id) or int(fight.jammed.get(spell_id, 0)) > 0
	var attack := Game.attack_tile()
	for i in cell_panels.size():
		var r := i / 6
		var c := i % 6
		var type := str(fight.board.cell(r, c))
		var icon: TextureRect = cell_icons[i]
		icon.texture = _tile_texture(type if type != "baguette" else attack)
		var cursed: bool = fight.board.is_cursed(r, c)
		var hot := selected == Vector2i(r, c) or drag_from == Vector2i(r, c)
		icon.modulate = Color(1, 0.45, 0.42) if cursed else Color.WHITE
		(cell_panels[i] as Panel).add_theme_stylebox_override("panel", _cell_style(hot, cursed))
	call_deferred("_publish_debug")


func _show_enemy_card(fight) -> void:
	var enemy_id := str(fight.enemy.get("id", ""))
	var subtype := str(fight.enemy.get("subtype", "a"))
	card_name.text = str(fight.enemy.get("name", ""))
	if enemy_id == "pigeon":
		photo.material = ink_mat
		photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		var image := str(Game.last_reveal.get("image", ""))
		photo.texture = load(image) if image != "" and ResourceLoader.exists(image) else null
		return
	photo.material = null
	photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var sprite := _portrait("%s_%s" % [enemy_id, subtype])
	if sprite == null:
		photo.material = ink_mat
		photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		var fallback := str(Game.last_reveal.get("image", ""))
		photo.texture = load(fallback) if fallback != "" and ResourceLoader.exists(fallback) else null
	else:
		photo.texture = sprite


func _input(event: InputEvent) -> void:
	if animating:
		get_viewport().set_input_as_handled()
		return
	if not is_visible_in_tree() or Game.battle == null or Game.battle.over:
		return
	if event is InputEventScreenTouch:
		_on_screen_touch(event as InputEventScreenTouch)
		return
	if event is InputEventScreenDrag:
		_on_screen_drag(event as InputEventScreenDrag)
		return
	if Time.get_ticks_msec() < last_touch_ms:
		if event is InputEventMouseButton or event is InputEventMouseMotion:
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_on_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion and gesture_pointer == -1:
		_move((event as InputEventMouseMotion).position)


func _on_screen_touch(touch: InputEventScreenTouch) -> void:
	var pos := _viewport_point(touch.position)
	if touch.pressed:
		var cell := _cell_at(pos)
		if cell.x < 0:
			return
		if _begin(cell, pos, touch.index, "touch"):
			get_viewport().set_input_as_handled()
		return
	if touch.index != gesture_pointer:
		return
	_end(_viewport_point(touch.position))
	get_viewport().set_input_as_handled()


func _on_screen_drag(drag: InputEventScreenDrag) -> void:
	if drag.index != gesture_pointer:
		return
	_move(_viewport_point(drag.position))
	get_viewport().set_input_as_handled()


func _on_mouse_button(mouse: InputEventMouseButton) -> void:
	var pos := _viewport_point(mouse.position)
	if mouse.pressed:
		var cell := _cell_at(pos)
		if cell.x < 0:
			return
		if Time.get_ticks_msec() - last_gesture_ms < 90:
			get_viewport().set_input_as_handled()
			return
		if _begin(cell, pos, -1, "mouse"):
			pressing = true
			get_viewport().set_input_as_handled()
		return
	if gesture_pointer != -1:
		return
	pressing = false
	_end(pos)
	get_viewport().set_input_as_handled()


func _begin(cell: Vector2i, pos: Vector2, pointer: int, kind: String) -> bool:
	_update_cell_span()
	gesture_pointer = pointer
	gesture_from = cell
	gesture_origin = pos
	gesture_fired = false
	drag_from = cell
	last_kind = kind
	if pointer >= 0:
		last_touch_ms = Time.get_ticks_msec() + 500
	refresh()
	return true


func _move(pos: Vector2) -> void:
	if gesture_fired or gesture_from.x < 0:
		return
	var delta := pos - gesture_origin
	var limit := cell_span * 0.33
	if absf(delta.x) < limit and absf(delta.y) < limit:
		return
	var dest := gesture_from
	if absf(delta.x) >= absf(delta.y):
		dest.y += 1 if delta.x > 0.0 else -1
	else:
		dest.x += 1 if delta.y > 0.0 else -1
	if dest.x < 0 or dest.y < 0 or dest.x >= 5 or dest.y >= 6:
		return
	gesture_fired = true
	last_gesture_ms = Time.get_ticks_msec()
	_commit_swap(gesture_from, dest)


func _end(pos: Vector2) -> void:
	var from := gesture_from
	var fired := gesture_fired
	gesture_pointer = -2
	gesture_from = Vector2i(-1, -1)
	drag_from = Vector2i(-1, -1)
	gesture_fired = false
	if fired or from.x < 0:
		refresh()
		return
	_release(from, _cell_at(pos))


func _update_cell_span() -> void:
	if cell_panels.is_empty():
		return
	var size := (cell_panels[0] as Control).get_global_rect().size
	var span := minf(size.x, size.y)
	if span >= 8.0:
		cell_span = span


func _release(origin: Vector2i, landed: Vector2i) -> void:
	if origin.x < 0:
		refresh()
		return
	if landed.x < 0 or landed == origin:
		if selected.x >= 0 and selected != origin and _adjacent(selected, origin):
			_commit_swap(selected, origin)
			return
		selected = Vector2i(-1, -1) if selected == origin else origin
		refresh()
		return
	if _adjacent(origin, landed):
		_commit_swap(origin, landed)
		return
	selected = landed
	var fight = Game.battle
	if fight:
		fight.log_line = "Только соседние клетки."
	refresh()


func _commit_swap(a: Vector2i, b: Vector2i) -> void:
	if animating:
		return
	Sfx.note_input()
	var fight = Game.battle
	if fight == null:
		return
	if fight.board.is_cursed(a.x, a.y) or fight.board.is_cursed(b.x, b.y):
		fight.log_line = "Эту клетку не сдвинуть."
		selected = b
		refresh()
		return
	animating = true
	var before_hp := int(fight.hp)
	var before_enemy := int(fight.enemy.get("hp", 0))
	var before_shield := int(fight.shield)
	var ghosts := _capture_ghosts()
	await _slide_ghosts(ghosts, a, b)
	var moved: bool = fight.player_swap(a.x, a.y, b.x, b.y)
	if not moved:
		await _slide_ghosts(ghosts, a, b)
		_free_ghosts(ghosts)
		_show_icons()
		selected = b
		animating = false
		refresh()
		return
	await _play_steps(fight.board.anim_steps, ghosts)
	selected = Vector2i(-1, -1)
	Sfx.play("ui/bad" if fight.hp < before_hp or not fight.victory else "ui/good", -6.0)
	animating = false
	refresh()
	_react(before_hp, before_enemy, before_shield, fight)


func _capture_ghosts() -> Dictionary:
	var ghosts := {}
	for i in cell_panels.size():
		var cell := Vector2i(i / 6, i % 6)
		var ghost := _ghost(cell)
		if ghost != null:
			ghosts["%d,%d" % [cell.x, cell.y]] = ghost
	return ghosts


func _slide_ghosts(ghosts: Dictionary, a: Vector2i, b: Vector2i) -> void:
	var key_a := "%d,%d" % [a.x, a.y]
	var key_b := "%d,%d" % [b.x, b.y]
	if not ghosts.has(key_a) or not ghosts.has(key_b):
		return
	var ghost_a: TextureRect = ghosts[key_a]
	var ghost_b: TextureRect = ghosts[key_b]
	var pos_a := ghost_a.position
	var pos_b := ghost_b.position
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(ghost_a, "position", pos_b, 0.16)
	tween.tween_property(ghost_b, "position", pos_a, 0.16)
	await tween.finished
	ghosts[key_a] = ghost_b
	ghosts[key_b] = ghost_a


func _free_ghosts(ghosts: Dictionary) -> void:
	for key in ghosts.keys():
		(ghosts[key] as Node).queue_free()


func _play_steps(steps: Array, ghosts: Dictionary) -> void:
	for step in steps:
		var op := str(step.get("op", ""))
		if op == "clear":
			var tween := create_tween()
			tween.set_parallel(true)
			var used := false
			for pos in step.get("cells", []):
				var key := "%d,%d" % [int(pos[0]), int(pos[1])]
				if not ghosts.has(key):
					continue
				var ghost: TextureRect = ghosts[key]
				ghost.pivot_offset = ghost.size * 0.5
				tween.tween_property(ghost, "scale", Vector2(0.15, 0.15), 0.14)
				tween.tween_property(ghost, "modulate:a", 0.0, 0.14)
				used = true
			if used:
				await tween.finished
			else:
				tween.kill()
			for pos in step.get("cells", []):
				var key := "%d,%d" % [int(pos[0]), int(pos[1])]
				if ghosts.has(key):
					(ghosts[key] as Node).queue_free()
					ghosts.erase(key)
		elif op == "drop":
			var tween := create_tween()
			tween.set_parallel(true)
			tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			var moved := {}
			var used := false
			for move in step.get("moves", []):
				var from_key := "%d,%d" % [int(move[0]), int(move[1])]
				var to_cell := Vector2i(int(move[2]), int(move[3]))
				if not ghosts.has(from_key):
					continue
				var ghost: TextureRect = ghosts[from_key]
				tween.tween_property(ghost, "position", _cell_local(to_cell).position, 0.2)
				moved["%d,%d" % [to_cell.x, to_cell.y]] = ghost
				ghosts.erase(from_key)
				used = true
			for spawn in step.get("spawns", []):
				var to_cell := Vector2i(int(spawn[0]), int(spawn[1]))
				var ghost := _ghost(to_cell, _tile_texture(str(spawn[2])))
				if ghost == null:
					continue
				var dest: Vector2 = ghost.position
				ghost.position = dest + Vector2(0, -_cell_local(to_cell).size.y * 1.2)
				tween.tween_property(ghost, "position", dest, 0.22)
				moved["%d,%d" % [to_cell.x, to_cell.y]] = ghost
				used = true
			for key in ghosts.keys():
				moved[key] = ghosts[key]
			if used:
				await tween.finished
			else:
				tween.kill()
			ghosts = moved
		elif op == "shuffle":
			break
	for key in ghosts.keys():
		(ghosts[key] as Node).queue_free()
	_show_icons()


func _ghost(cell: Vector2i, texture: Texture2D = null) -> TextureRect:
	var index := cell.x * 6 + cell.y
	if index < 0 or index >= cell_icons.size():
		return null
	var icon: TextureRect = cell_icons[index]
	var ghost := TextureRect.new()
	ghost.texture = texture if texture != null else icon.texture
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ghost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var rect := _cell_local(cell)
	ghost.position = rect.position
	ghost.size = rect.size
	ghost.pivot_offset = rect.size * 0.5
	add_child(ghost)
	if rect.size.x > 4.0:
		icon.modulate.a = 0.0
	return ghost


func _show_icons() -> void:
	for icon in cell_icons:
		(icon as CanvasItem).modulate.a = 1.0


func _cell_local(cell: Vector2i) -> Rect2:
	var index := cell.x * 6 + cell.y
	var panel := cell_panels[index] as Control
	var global_rect := panel.get_global_rect()
	var origin := global_rect.position - get_global_rect().position
	return Rect2(origin, global_rect.size)


func _react(before_hp: int, before_enemy: int, before_shield: int, fight) -> void:
	var dealt := before_enemy - int(fight.enemy.get("hp", before_enemy))
	var hurt := before_hp - int(fight.hp)
	var healed := int(fight.hp) - before_hp
	var shielded := int(fight.shield) - before_shield
	if dealt > 0 and mob_card != null:
		var number := _line("-%d" % dealt, 36, display)
		number.add_theme_color_override("font_color", Palette.MARKER)
		var spot := mob_card.get_global_rect()
		number.position = get_global_transform().affine_inverse() * (spot.position + Vector2(spot.size.x * 0.55, 28))
		number.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(number)
		var base := mob_card.rotation
		var pop := create_tween()
		pop.set_parallel(true)
		pop.tween_property(mob_card, "rotation", base + 0.04, 0.05)
		pop.tween_property(number, "position:y", number.position.y - 42, 0.28)
		pop.tween_property(number, "modulate:a", 0.0, 0.28)
		pop.chain().tween_property(mob_card, "rotation", base, 0.08)
		pop.finished.connect(number.queue_free)
	if hurt > 0 and hero_label != null:
		var shake := create_tween()
		shake.tween_property(hero_label, "modulate", Color(1, 0.4, 0.35), 0.06)
		shake.tween_property(hero_label, "modulate", Color.WHITE, 0.12)
	if healed > 0 or shielded > 0:
		var target: Control = hero_label
		target.pivot_offset = target.size * 0.5
		var pop := create_tween()
		pop.tween_property(target, "scale", Vector2(1.25, 1.25), 0.08)
		pop.tween_property(target, "scale", Vector2.ONE, 0.12)


func _cast(spell_id: String) -> void:
	if Time.get_ticks_msec() - last_gesture_ms < 90:
		return
	last_gesture_ms = Time.get_ticks_msec()
	Sfx.note_input()
	if Game.battle != null and Game.battle.cast(spell_id):
		Sfx.play("ui/tap", -8.0)
		selected = Vector2i(-1, -1)
		refresh()


func _leave() -> void:
	if Game.battle == null or not Game.battle.over:
		return
	Sfx.note_input()
	finished.emit(Game.battle.victory)


func _viewport_point(point: Vector2) -> Vector2:
	if _hits_board(point):
		return point
	var win := Vector2(DisplayServer.window_get_size())
	var view := get_viewport().get_visible_rect().size
	if win.x > 2.0 and view.x > 2.0 and (absf(win.x - view.x) > 2.0 or absf(win.y - view.y) > 2.0):
		var scaled := Vector2(point.x / win.x * view.x, point.y / win.y * view.y)
		if _hits_board(scaled):
			return scaled
	return point


func _hits_board(point: Vector2) -> bool:
	if grid != null and grid.get_global_rect().grow(12.0).has_point(point):
		return true
	return _cell_at(point).x >= 0


func _cell_at(point: Vector2) -> Vector2i:
	var nearest := Vector2i(-1, -1)
	var nearest_d := 1.0e12
	for i in cell_panels.size():
		var rect := (cell_panels[i] as Control).get_global_rect()
		if rect.has_point(point):
			return Vector2i(i / 6, i % 6)
		var dist := rect.get_center().distance_squared_to(point)
		if dist < nearest_d:
			nearest_d = dist
			nearest = Vector2i(i / 6, i % 6)
	if grid != null and grid.get_global_rect().grow(12.0).has_point(point):
		return nearest
	return Vector2i(-1, -1)


func _adjacent(a: Vector2i, b: Vector2i) -> bool:
	return absi(a.x - b.x) + absi(a.y - b.y) == 1


func _publish_debug() -> void:
	if not OS.is_debug_build() or not OS.has_feature("web"):
		return
	var view := get_viewport().get_visible_rect().size
	if view.x < 2.0:
		view = Vector2(720, 1280)
	var bits: PackedStringArray = []
	for panel in cell_panels:
		var center := (panel as Control).get_global_rect().get_center()
		bits.append("%.1f,%.1f" % [center.x / view.x, center.y / view.y])
	var fight = Game.battle
	var log := ""
	var hp := 0
	var over := false
	if fight:
		log = str(fight.log_line).replace("'", "").replace("\n", " ")
		hp = int(fight.hp)
		over = bool(fight.over)
	var js := "window.DOOR_CELLS='%s';window.DOOR_LOG='%s';window.DOOR_HP=%d;window.DOOR_OVER=%s;window.DOOR_KIND='%s';" % ["|".join(bits), log, hp, "true" if over else "false", last_kind]
	JavaScriptBridge.eval(js, true)


func _tile_texture(kind: String) -> Texture2D:
	if kind == "rifle":
		kind = "rifle_ammo"
	var path := "res://art/tiles/%s.png" % kind
	if ResourceLoader.exists(path):
		return load(path)
	return null


func _portrait(kind: String) -> Texture2D:
	if kind == "pigeon":
		var bird := "res://art/scenes/pigeon.webp"
		return load(bird) if ResourceLoader.exists(bird) else null
	var path := "res://art/mobs/%s.png" % kind
	if ResourceLoader.exists(path):
		return load(path)
	return null


func _paint_button(button: Button, fill: Color, border: Color) -> void:
	button.add_theme_stylebox_override("normal", _frame(fill, border, 4))
	button.add_theme_stylebox_override("hover", _frame(fill.lightened(0.08), Palette.MARKER, 4))
	button.add_theme_stylebox_override("pressed", _frame(fill.darkened(0.08), Palette.MARKER, 4))
	button.add_theme_stylebox_override("disabled", _frame(Color(fill.r, fill.g, fill.b, 0.45), Palette.MUTED, 3))
	button.add_theme_stylebox_override("focus", _frame(fill, border, 4))
	button.add_theme_color_override("font_color", Palette.PAPER_ON_INK)
	button.add_theme_color_override("font_hover_color", Palette.PAPER_ON_INK)
	button.add_theme_color_override("font_disabled_color", Palette.MUTED)


func _frame(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_border_width_all(width)
	style.border_color = border
	style.set_corner_radius_all(3)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 4
	style.shadow_offset = Vector2(3, 4)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


func _cell_style(hot: bool, cursed: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("14110f")
	style.set_corner_radius_all(2)
	style.set_border_width_all(4 if hot else 2)
	style.border_color = Palette.MARKER if hot or cursed else Color("6d6254")
	return style


func _bar() -> Array:
	var bg := Panel.new()
	bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bg.custom_minimum_size = Vector2(0, 26)
	var style := _frame(Color("101614"), Palette.INK, 2)
	style.set_corner_radius_all(6)
	style.shadow_size = 0
	bg.add_theme_stylebox_override("panel", style)
	var fill := ColorRect.new()
	fill.anchor_left = 0.0
	fill.anchor_right = 0.0
	fill.anchor_top = 0.0
	fill.anchor_bottom = 1.0
	fill.offset_left = 4
	fill.offset_top = 4
	fill.offset_bottom = -4
	fill.offset_right = 4
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(fill)
	return [bg, fill]


func _set_fill(fill: ColorRect, ratio: float) -> void:
	var clamped := clampf(ratio, 0.0, 1.0)
	fill.anchor_left = 0.0
	fill.anchor_right = clamped
	fill.offset_left = 4.0
	fill.offset_right = -4.0 if clamped > 0.04 else 0.0


func _process(_delta: float) -> void:
	if not is_visible_in_tree() or Game.battle == null:
		return
	var enemy_max := maxi(1, int(Game.battle.enemy.get("max_hp", 1)))
	_set_fill(enemy_fill, float(int(Game.battle.enemy["hp"])) / float(enemy_max))
	if OS.is_debug_build() and OS.has_feature("web"):
		_publish_debug()


func _single_line(text: String, size: int) -> Label:
	var label := _line(text, size, display)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _line(text: String, size: int, font: Font) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Palette.INK)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

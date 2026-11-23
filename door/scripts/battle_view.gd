extends Control
## Экран боя: карточка, арена, три заклинания, поле 6×5.

const Palette := preload("res://scripts/door_theme.gd")

signal finished(won: bool)

var story: Label
var enemy_art: TextureRect
var log_label: Label
var hero_bar: Label
var enemy_bar: Label
var intent: Label
var energy_label: Label
var footer: Label
var grid: GridContainer
var cells: Array = []
var spell_buttons: Dictionary = {}
var leave: Button
var stamp: Label
var selected: Vector2i = Vector2i(-1, -1)
var display: Font
var body: Font


func setup(display_font: Font, body_font: Font) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	display = display_font
	body = body_font
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 16
	box.offset_top = 12
	box.offset_right = -16
	box.offset_bottom = -12
	box.add_theme_constant_override("separation", 6)
	add_child(box)
	stamp = _line("БОЙ", 28)
	stamp.add_theme_color_override("font_color", Palette.MARKER)
	box.add_child(stamp)
	box.add_child(_label_bind("story", 22))
	enemy_art = TextureRect.new()
	enemy_art.custom_minimum_size = Vector2(96, 96)
	enemy_art.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	enemy_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(enemy_art)
	var bars := HBoxContainer.new()
	bars.add_theme_constant_override("separation", 8)
	hero_bar = _line("Вы 40", 22)
	enemy_bar = _line("Враг", 22)
	hero_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enemy_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bars.add_child(hero_bar)
	bars.add_child(enemy_bar)
	box.add_child(bars)
	intent = _line("", 20)
	box.add_child(intent)
	var spells := HBoxContainer.new()
	spells.add_theme_constant_override("separation", 6)
	for item in [["shot", "Выстрел\n2"], ["grenade", "Граната\n4"], ["kit", "Аптечка\n3"]]:
		var button := Button.new()
		button.text = item[1]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 64)
		button.add_theme_font_override("font", display)
		button.add_theme_font_size_override("font_size", 22)
		_style_button(button, false)
		var spell_id := str(item[0])
		button.pressed.connect(func() -> void: _cast(spell_id))
		spells.add_child(button)
		spell_buttons[spell_id] = button
	box.add_child(spells)
	energy_label = _line("энергия 0/10", 20)
	box.add_child(energy_label)
	grid = GridContainer.new()
	grid.columns = 6
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	box.add_child(grid)
	for i in 30:
		var button := TextureButton.new()
		button.ignore_texture_size = true
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		button.custom_minimum_size = Vector2(0, 72)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var index := i
		button.pressed.connect(func() -> void: _tap(index))
		grid.add_child(button)
		cells.append(button)
	log_label = _line("", 20)
	box.add_child(log_label)
	footer = _line("", 20)
	box.add_child(footer)
	leave = Button.new()
	leave.text = "Дальше"
	leave.visible = false
	leave.custom_minimum_size = Vector2(0, 64)
	leave.add_theme_font_override("font", display)
	leave.add_theme_font_size_override("font_size", 28)
	_style_button(leave, true)
	leave.pressed.connect(_leave)
	box.add_child(leave)


func refresh() -> void:
	var fight = Game.battle
	if fight == null:
		return
	story.text = Game.battle_blurb()
	hero_bar.text = "вы %d/%d  щит %d" % [fight.hp, fight.hero_max(), fight.shield]
	var extra := ""
	if fight.minion_hp > 0:
		extra = " +%d" % fight.minion_hp
	enemy_bar.text = "%s %d/%d%s" % [fight.enemy["name"], int(fight.enemy["hp"]), int(fight.enemy["max_hp"]), extra]
	intent.text = "задумано: %s" % str(fight.enemy.get("intent", ""))
	var portrait := "pigeon" if str(fight.enemy.get("id", "")) == "pigeon" else "%s_%s" % [str(fight.enemy.get("id", "")), str(fight.enemy.get("subtype", "a"))]
	enemy_art.texture = _tile_texture(portrait) if portrait == "pigeon" else _mob_texture(portrait)
	energy_label.text = "энергия %d/10 · %s" % [fight.energy, _weapon_short(fight.weapon)]
	log_label.text = fight.log_line
	footer.text = Game.battle_reward_text()
	leave.visible = fight.over
	leave.text = "Дальше" if fight.victory else "Это конец"
	for spell_id in spell_buttons.keys():
		var button: Button = spell_buttons[spell_id]
		button.disabled = fight.over or fight.turn != "player" or fight.swapped or fight.energy < fight._spell_cost(spell_id) or int(fight.jammed.get(spell_id, 0)) > 0
	var attack := Game.attack_tile()
	for i in cells.size():
		var r := i / 6
		var c := i % 6
		var type := str(fight.board.cell(r, c))
		var button: TextureButton = cells[i]
		button.texture_normal = _tile_texture(type if type != "baguette" else attack)
		button.modulate = Color(1, 0.45, 0.4) if fight.board.is_cursed(r, c) else (Color(1, 0.9, 0.4) if selected == Vector2i(r, c) else Color.WHITE)
		button.disabled = fight.over


func _cast(spell_id: String) -> void:
	Sfx.note_input()
	if Game.battle.cast(spell_id):
		Sfx.play("ui/tap", -8.0)
		refresh()


func _tap(index: int) -> void:
	Sfx.note_input()
	var fight = Game.battle
	if fight == null or fight.over:
		return
	var r := index / 6
	var c := index % 6
	if selected.x < 0:
		selected = Vector2i(r, c)
		refresh()
		return
	if selected == Vector2i(r, c):
		selected = Vector2i(-1, -1)
		refresh()
		return
	var moved: bool = fight.player_swap(selected.x, selected.y, r, c)
	selected = Vector2i(-1, -1)
	if moved:
		Sfx.play("ui/bad" if fight.hp < int(Game.stats.get("health", fight.hp)) or not fight.victory else "ui/good", -6.0)
	refresh()


func _leave() -> void:
	if Game.battle == null or not Game.battle.over:
		return
	Sfx.note_input()
	finished.emit(Game.battle.victory)


func _tile_texture(kind: String) -> Texture2D:
	if kind == "rifle":
		kind = "rifle_ammo"
	var path := "res://art/tiles/%s.png" % kind
	if ResourceLoader.exists(path):
		return load(path)
	return null


func _mob_texture(kind: String) -> Texture2D:
	var path := "res://art/mobs/%s.png" % kind
	if ResourceLoader.exists(path):
		return load(path)
	return null


func _style_button(button: Button, primary: bool) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Palette.PANEL if primary else Color(Palette.INK_DEEP.r, Palette.INK_DEEP.g, Palette.INK_DEEP.b, 0.2)
	normal.set_border_width_all(2)
	normal.border_color = Palette.INK
	normal.set_corner_radius_all(6)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", normal)
	button.add_theme_stylebox_override("pressed", normal)
	button.add_theme_color_override("font_color", Palette.PAPER_ON_INK if primary else Palette.INK)
	button.add_theme_color_override("font_hover_color", Palette.PAPER_ON_INK)
	button.add_theme_color_override("font_disabled_color", Palette.MUTED)


func _line(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", body)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Palette.INK)
	return label


func _label_bind(slot: String, size: int) -> Label:
	var label := _line("", size)
	set(slot, label)
	return label


func _weapon_short(id: String) -> String:
	match id:
		"pan":
			return "сковорода"
		"crowbar":
			return "лом"
		"rifle":
			return "винтовка"
		_:
			return "батон"

extends Control
## Экран правки текстов и чисел. В редакторе Godot пишет в data/events.json,
## в сборке — в user://events.json. Случайные исходы (roll) здесь не затираются.

var on_close: Callable = Callable()
var working: Dictionary = {}
var selected: int = -1
var list: ItemList
var status: Label
var setup_edit: TextEdit
var image_edit: LineEdit
var sound_edit: LineEdit
var fields: Dictionary = {}
var roll_note: Label
var lock := false

const Palette := preload("res://scripts/door_theme.gd")
const PAPER := Palette.PAPER
const MUTED := Palette.MUTED
const AMBER := Palette.INK
const INK := Palette.PAPER_ON_INK
const STATS: Array[String] = ["food", "health", "sanity", "ammo"]


func setup(close_callback: Callable) -> void:
	on_close = close_callback
	_build()
	reload()


func reload() -> void:
	Game.load_data()
	var parsed: Variant = JSON.parse_string(JSON.stringify(Game.data))
	working = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
	if not working.has("events"):
		working["events"] = []
	_fill_list()
	status.text = "Источник: %s" % Game.source_label


func _build() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 20)
	add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	scroll.add_child(box)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	var back := _button("Назад", false)
	back.pressed.connect(func() -> void:
		if on_close.is_valid():
			on_close.call()
	)
	var save := _button("Сохранить", true)
	save.pressed.connect(_save)
	bar.add_child(back)
	bar.add_child(save)
	box.add_child(bar)

	status = _label("…")
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(status)

	list = ItemList.new()
	list.custom_minimum_size = Vector2(0, 220)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_font_size_override("font_size", 22)
	list.item_selected.connect(func(i: int) -> void:
		if lock:
			return
		_on_selected(i)
	)
	box.add_child(list)

	setup_edit = _area("Ситуация", 4)
	box.add_child(setup_edit.get_parent())
	image_edit = LineEdit.new()
	image_edit.placeholder_text = "картинка: пусто = scenes/<сцена>"
	image_edit.custom_minimum_size = Vector2(0, 52)
	image_edit.add_theme_font_size_override("font_size", 22)
	box.add_child(image_edit)
	sound_edit = LineEdit.new()
	sound_edit.placeholder_text = "звук: пусто = scenes/<сцена>"
	sound_edit.custom_minimum_size = Vector2(0, 52)
	sound_edit.add_theme_font_size_override("font_size", 22)
	box.add_child(sound_edit)

	for which in ["a", "b"]:
		var title := "Выбор А" if which == "a" else "Выбор Б"
		box.add_child(_label(title))
		var label_edit := LineEdit.new()
		label_edit.placeholder_text = "Подпись кнопки"
		label_edit.custom_minimum_size = Vector2(0, 52)
		label_edit.add_theme_font_size_override("font_size", 22)
		box.add_child(label_edit)
		var text_edit := _area("Исход", 3)
		box.add_child(text_edit.get_parent())
		var spins := HBoxContainer.new()
		spins.add_theme_constant_override("separation", 6)
		var spin_map := {}
		for stat_id in STATS:
			var spin := SpinBox.new()
			spin.min_value = -9
			spin.max_value = 9
			spin.step = 1
			spin.custom_minimum_size = Vector2(70, 48)
			spin.prefix = stat_id.substr(0, 1)
			spins.add_child(spin)
			spin_map[stat_id] = spin
		box.add_child(spins)
		fields[which] = {"label": label_edit, "text": text_edit, "spins": spin_map}

	roll_note = _label("")
	roll_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(roll_note)

	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 8)
	var add := _button("Новое", false)
	add.pressed.connect(_add)
	var remove := _button("Удалить", false)
	remove.pressed.connect(_delete)
	var reset := _button("Сбросить user://", false)
	reset.pressed.connect(func() -> void:
		Game.clear_override()
		reload()
		status.text = "Правки сборки сброшены. В редакторе игра читает data/events.json."
	)
	tools.add_child(add)
	tools.add_child(remove)
	box.add_child(tools)
	box.add_child(reset)
	box.add_child(_label("Полная правка условий, флагов и случайных исходов — в доке «События» редактора Godot или прямо в data/events.json."))


func _fill_list() -> void:
	lock = true
	list.clear()
	var events: Array = working.get("events", [])
	for ev in events:
		if typeof(ev) != TYPE_DICTIONARY:
			list.add_item("?")
		else:
			list.add_item(str(ev.get("id", "?")))
	if events.is_empty():
		selected = -1
		lock = false
		return
	selected = clampi(selected, 0, events.size() - 1)
	list.select(selected)
	lock = false
	_load_selected()


func _on_selected(index: int) -> void:
	_store_selected()
	selected = index
	_load_selected()


func _current() -> Dictionary:
	var events: Array = working.get("events", [])
	if selected < 0 or selected >= events.size():
		return {}
	if typeof(events[selected]) != TYPE_DICTIONARY:
		return {}
	return events[selected]


func _load_selected() -> void:
	var ev := _current()
	setup_edit.text = str(ev.get("setup", ""))
	image_edit.text = str(ev.get("image", ""))
	sound_edit.text = str(ev.get("sound", ""))
	for which in ["a", "b"]:
		var branch: Dictionary = ev.get(which, {})
		fields[which]["label"].text = str(branch.get("label", ""))
		fields[which]["text"].text = str(branch.get("text", ""))
		var effects: Dictionary = branch.get("effects", {})
		for stat_id in STATS:
			(fields[which]["spins"][stat_id] as SpinBox).value = int(effects.get(stat_id, 0))
	var has_roll := false
	for which in ["a", "b"]:
		var branch: Dictionary = ev.get(which, {})
		if branch.has("roll"):
			has_roll = true
	roll_note.text = "У выбора есть случайный исход (roll). Числа здесь не перезапишут его — правь roll в JSON." if has_roll else "Числа — изменение еды, здоровья, рассудка и патронов."


func _store_selected() -> void:
	var ev := _current()
	if ev.is_empty():
		return
	ev["setup"] = setup_edit.text
	var picture := image_edit.text.strip_edges()
	if picture == "":
		ev.erase("image")
	else:
		ev["image"] = picture
	var clip := sound_edit.text.strip_edges()
	if clip == "":
		ev.erase("sound")
	else:
		ev["sound"] = clip
	for which in ["a", "b"]:
		if typeof(ev.get(which)) != TYPE_DICTIONARY:
			ev[which] = {}
		var branch: Dictionary = ev[which]
		branch["label"] = fields[which]["label"].text
		branch["text"] = fields[which]["text"].text
		if branch.has("roll"):
			continue
		var effects := {}
		for stat_id in STATS:
			var value := int((fields[which]["spins"][stat_id] as SpinBox).value)
			if value != 0:
				effects[stat_id] = value
		if effects.is_empty():
			branch.erase("effects")
		else:
			branch["effects"] = effects


func _save() -> void:
	_store_selected()
	status.text = Game.save_data(working)
	reload()


func _add() -> void:
	_store_selected()
	var events: Array = working.get("events", [])
	var number := events.size() + 1
	var id := "event_%d" % number
	while Game.by_id.has(id) or _has_id(id):
		number += 1
		id = "event_%d" % number
	events.append({
		"id": id,
		"once": true,
		"weight": 1,
		"scene": "door",
		"when": {"min_day": 1, "max_day": 30},
		"setup": "Кто-то стучит. Коротко, как в хорошем ролике.",
		"a": {"label": "Открыть", "text": "Ты открыл. Дальше допиши сам.", "effects": {"sanity": -1}},
		"b": {"label": "Не открывать", "text": "Дверь осталась дверью.", "effects": {"sanity": 1}},
	})
	selected = events.size() - 1
	_fill_list()


func _has_id(id: String) -> bool:
	for ev in working.get("events", []):
		if typeof(ev) == TYPE_DICTIONARY and str(ev.get("id", "")) == id:
			return true
	return false


func _delete() -> void:
	var events: Array = working.get("events", [])
	if selected < 0 or selected >= events.size():
		return
	events.remove_at(selected)
	selected = mini(selected, events.size() - 1)
	_fill_list()


func _area(title: String, lines: int) -> TextEdit:
	var wrap := VBoxContainer.new()
	wrap.add_child(_label(title))
	var edit := TextEdit.new()
	edit.custom_minimum_size = Vector2(0, 36 * lines)
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	edit.add_theme_font_size_override("font_size", 20)
	wrap.add_child(edit)
	return edit


func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", MUTED)
	label.add_theme_font_size_override("font_size", 18)
	return label


func _button(text: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 64)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", PAPER if primary else AMBER)
	var style := StyleBoxFlat.new()
	style.bg_color = AMBER if primary else PAPER
	style.set_border_width_all(3)
	style.border_color = AMBER
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_right = 14
	style.corner_radius_bottom_left = 14
	style.content_margin_left = 10
	style.content_margin_right = 10
	button.add_theme_stylebox_override("normal", style)
	return button

@tool
extends Control
class_name CatalogEditor
## Общий редактор чисел для дока Godot и для экрана в игре.

signal save_pressed
signal reload_pressed

var dense := false

var _bundle: Dictionary = {}
var _section := 0
var _index := 0
var _lock := false
var _status: Label
var _section_box: OptionButton
var _list: ItemList
var _form: VBoxContainer
var _new_button: Button
var _delete_button: Button
var _id_line: LineEdit
var _id_owner: Dictionary = {}

const BODY_FONT := preload("res://fonts/Manrope.ttf")
const SECTIONS: Array[String] = ["Баланс", "Редкости", "Края", "Нечисть", "Снаряды", "Улучшения"]
const RARITY_ORDER: Array[String] = ["common", "uncommon", "rare", "epic"]
const SHAPES: Array[String] = ["blob", "squat", "tall", "horned", "wispy"]


func _ready() -> void:
	var theme := Theme.new()
	theme.default_font = BODY_FONT
	self.theme = theme
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	scroll.add_child(box)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	var save := _button("Сохранить")
	save.pressed.connect(func() -> void:
		_flush_id()
		save_pressed.emit()
	)
	var reload := _button("Перечитать")
	reload.pressed.connect(func() -> void: reload_pressed.emit())
	bar.add_child(save)
	bar.add_child(reload)
	box.add_child(bar)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", _font())
	box.add_child(_status)

	_section_box = OptionButton.new()
	for title in SECTIONS:
		_section_box.add_item(title)
	_section_box.item_selected.connect(func(which: int) -> void:
		if _lock:
			return
		_flush_id()
		_section = which
		_index = 0
		_fill()
	)
	box.add_child(_section_box)

	_list = ItemList.new()
	_list.custom_minimum_size = Vector2(0, 140 if dense else 180)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.item_selected.connect(func(which: int) -> void:
		if _lock:
			return
		_flush_id()
		_index = which
		_rebuild_form()
	)
	box.add_child(_list)

	_form = VBoxContainer.new()
	_form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_form.add_theme_constant_override("separation", 6)
	box.add_child(_form)

	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 8)
	_new_button = _button("Добавить")
	_delete_button = _button("Удалить")
	_new_button.pressed.connect(_add_entry)
	_delete_button.pressed.connect(_delete_entry)
	tools.add_child(_new_button)
	tools.add_child(_delete_button)
	box.add_child(tools)

	if not _bundle.is_empty():
		_fill()


func set_bundle(data: Dictionary) -> void:
	_bundle = data.duplicate(true)
	_ensure_shape()
	_index = 0
	if is_node_ready():
		_fill()


func edited_bundle() -> Dictionary:
	_flush_id()
	return _bundle.duplicate(true)


func set_status(text: String) -> void:
	if _status:
		_status.text = text


func debug_open_section(which: int) -> void:
	_flush_id()
	_section = clampi(which, 0, SECTIONS.size() - 1)
	_index = 0
	if _section_box:
		_lock = true
		_section_box.select(_section)
		_lock = false
	if is_node_ready():
		_fill()


func debug_nudge_first_spin() -> Dictionary:
	if _form == null:
		return {}
	var spins := _form.find_children("", "SpinBox", true, false)
	if spins.is_empty():
		return {}
	var spin := spins[0] as SpinBox
	spin.value = spin.value + spin.step
	return {"key": str(spin.get_meta("key", "")), "value": spin.value}


func _fill() -> void:
	if _list == null:
		return
	_lock = true
	_list.clear()
	var entries := _entries()
	_list.visible = _section != 0
	_new_button.visible = _section != 0
	_delete_button.visible = _section != 0
	for entry in entries:
		_list.add_item(_entry_label(entry))
	if not entries.is_empty():
		_index = clampi(_index, 0, entries.size() - 1)
		_list.select(_index)
	else:
		_index = 0
	_lock = false
	_rebuild_form()


func _entries() -> Array:
	match _section:
		1:
			var ids: Array = []
			var table: Dictionary = _balance().get("rarity", {})
			for rarity_id in RARITY_ORDER:
				if table.has(rarity_id):
					ids.append(rarity_id)
			for rarity_id in table.keys():
				if not ids.has(rarity_id):
					ids.append(str(rarity_id))
			return ids
		2:
			return _rows("biomes")
		3:
			return _rows("creatures")
		4:
			return _rows("items")
		5:
			return _rows("upgrades")
		_:
			return []


func _entry_label(entry: Variant) -> String:
	if _section == 1:
		var row: Dictionary = _balance().get("rarity", {}).get(str(entry), {})
		return "%s · %s" % [entry, row.get("label", "")]
	if typeof(entry) != TYPE_DICTIONARY:
		return "?"
	return str(entry.get("name", entry.get("id", "?")))


func _rebuild_form() -> void:
	_id_line = null
	_id_owner = {}
	_clear(_form)
	match _section:
		0:
			_build_balance()
		1:
			_build_rarity()
		2:
			_build_fields(_current_row(), [
				["id", "id", "id"],
				["name", "название", "string"],
				["unlock_distance", "дальность открытия, м", "float"],
				["ground", "цвет земли #rrggbb", "string"],
				["blurb", "фраза при открытии", "text"],
			])
		3:
			_build_fields(_current_row(), [
				["id", "id", "id"],
				["name", "имя", "string"],
				["biome", "край", "biome"],
				["rarity", "редкость", "rarity"],
				["weight", "вес появления", "int"],
				["income_scale", "множитель дохода", "float"],
				["shape", "фигура", "shape"],
				["color", "цвет #rrggbb", "string"],
				["line", "реплика", "text"],
			])
		4:
			_build_fields(_current_row(), [
				["id", "id", "id"],
				["name", "название", "string"],
				["price", "цена", "int"],
				["throw_mult", "множитель дальности", "float"],
				["lure", "приманка, гостей", "int"],
				["color", "цвет снаряда #rrggbb", "string"],
				["blurb", "подпись", "text"],
			])
		5:
			_build_fields(_current_row(), [
				["id", "id (throw_power, pen_slots, pen_income, lure)", "id"],
				["name", "название", "string"],
				["base_cost", "цена первого уровня", "int"],
				["growth", "рост цены", "float"],
				["max_level", "потолок уровней", "int"],
				["blurb", "подпись", "text"],
			])


func _build_balance() -> void:
	var data := _balance()
	_caption(_form, "Эти числа меняют игру. Блок «расчёт» нужен только симуляции.")
	for spec in [
		["base_distance", "минимальная дальность, м", "float"],
		["power_distance", "прибавка на полной силе, м", "float"],
		["throw_step", "прибавка замаха за уровень", "float"],
		["income_step", "прибавка кормёжки за уровень", "float"],
		["base_spawns", "гостей за бросок", "int"],
		["max_spawns", "потолок гостей", "int"],
		["lure_per_level", "гостей за уровень приманки", "int"],
		["start_pen", "мест в загоне сначала", "int"],
		["duplicate_bonus", "бонус повторной поимки", "float"],
		["duplicate_cap", "сколько повторов считаются", "int"],
		["offline_cap_sec", "потолок оффлайна, секунды", "int"],
		["start_currency", "гроши на старте", "float"],
		["meter_hz", "скорость полоски силы", "float"],
		["currency_one", "валюта, 1", "string"],
		["currency_few", "валюта, 2–4", "string"],
		["currency_many", "валюта, 5+", "string"],
	]:
		_add_spec(_form, data, spec)
	_caption(_form, "Только для расчёта баланса, в игре не используется.")
	var sim: Dictionary = data.get("sim", {})
	_add_spec(_form, sim, ["throw_cycle_sec", "секунд на бросок в расчёте", "float"])
	var rates: Dictionary = sim.get("catch_rate", {})
	for rarity_id in _rarity_ids():
		if not rates.has(rarity_id):
			rates[rarity_id] = 0.5
		_add_spec(_form, rates, [rarity_id, "шанс поимки «%s» в расчёте" % rarity_id, "float"])


func _build_rarity() -> void:
	var rarity_id := _current_rarity_id()
	if rarity_id == "":
		_caption(_form, "Редкостей нет.")
		return
	var row: Dictionary = _balance().rarity[rarity_id]
	_caption(_form, "Редкость задаёт доход, окно ловли и горсть грошей за поимку.")
	_form.add_child(_caption_label("id"))
	var line := LineEdit.new()
	line.text = rarity_id
	line.add_theme_font_size_override("font_size", _font())
	line.custom_minimum_size = Vector2(0, _control_h())
	_id_line = line
	_id_owner = {"kind": "rarity", "id": rarity_id}
	_form.add_child(line)
	for spec in [
		["label", "подпись", "string"],
		["income", "доход в секунду", "float"],
		["window", "секунд, чтобы успеть", "float"],
		["catch_bonus", "гроши сразу за поимку", "int"],
	]:
		_add_spec(_form, row, spec)


func _build_fields(row: Dictionary, specs: Array) -> void:
	if row.is_empty():
		_caption(_form, "Пока пусто. Нажми «Добавить».")
		return
	for spec in specs:
		_add_spec(_form, row, spec)


func _add_spec(parent: VBoxContainer, row: Dictionary, spec: Array) -> void:
	var key := str(spec[0])
	var label := str(spec[1])
	var kind := str(spec[2])
	_caption(parent, label)
	match kind:
		"string":
			var line := LineEdit.new()
			line.text = str(row.get(key, ""))
			line.custom_minimum_size = Vector2(0, _control_h())
			line.add_theme_font_size_override("font_size", _font())
			line.text_changed.connect(func(value: String) -> void:
				if _lock:
					return
				row[key] = value
				_refresh_list_label()
			)
			parent.add_child(line)
		"text":
			var area := TextEdit.new()
			area.text = str(row.get(key, ""))
			area.custom_minimum_size = Vector2(0, 78)
			area.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
			area.add_theme_font_size_override("font_size", _font())
			area.text_changed.connect(func() -> void:
				if _lock:
					return
				row[key] = area.text
				_refresh_list_label()
			)
			parent.add_child(area)
		"id":
			var line := LineEdit.new()
			line.text = str(row.get(key, ""))
			line.custom_minimum_size = Vector2(0, _control_h())
			line.add_theme_font_size_override("font_size", _font())
			_id_line = line
			_id_owner = row
			parent.add_child(line)
		"int", "float":
			var spin := SpinBox.new()
			spin.min_value = 0
			spin.max_value = 10000000
			spin.step = 1 if kind == "int" else 0.01
			spin.rounded = kind == "int"
			spin.custom_minimum_size = Vector2(160, _control_h())
			spin.set_meta("key", key)
			_lock = true
			spin.value = float(row.get(key, 0))
			_lock = false
			spin.value_changed.connect(func(value: float) -> void:
				if _lock:
					return
				row[key] = int(round(value)) if kind == "int" else snappedf(value, 0.0001)
			)
			parent.add_child(spin)
		"biome":
			_option_row(parent, row, key, _choice_ids(_rows("biomes")))
		"rarity":
			_option_row(parent, row, key, _rarity_ids())
		"shape":
			_option_row(parent, row, key, SHAPES)


func _option_row(parent: VBoxContainer, row: Dictionary, key: String, choices: Array) -> void:
	var box := OptionButton.new()
	box.add_theme_font_size_override("font_size", _font())
	var current := str(row.get(key, ""))
	var selected := 0
	if choices.is_empty():
		box.add_item("—")
	for i in choices.size():
		var id := str(choices[i])
		box.add_item(id)
		box.set_item_metadata(i, id)
		if id == current:
			selected = i
	_lock = true
	if box.item_count > 0:
		box.select(selected)
	_lock = false
	box.item_selected.connect(func(which: int) -> void:
		if _lock:
			return
		row[key] = str(box.get_item_metadata(which))
	)
	parent.add_child(box)


func _add_entry() -> void:
	_flush_id()
	match _section:
		1:
			var table: Dictionary = _balance().rarity
			var rarity_id := _unique_key("custom", table)
			table[rarity_id] = {"label": "новая", "income": 1, "window": 1.5, "catch_bonus": 8}
			_balance().sim.catch_rate[rarity_id] = 0.5
			_index = _rarity_ids().find(rarity_id)
		2:
			var biomes := _rows("biomes")
			var distance := 0.0
			if not biomes.is_empty():
				distance = float(biomes[biomes.size() - 1].get("unlock_distance", 0)) + 40.0
			biomes.append({
				"id": _unique_id("biome", biomes),
				"name": "Новый край",
				"unlock_distance": distance,
				"ground": "#445044",
				"blurb": "",
			})
			_index = biomes.size() - 1
		3:
			var creatures := _rows("creatures")
			var biome_id := "yard"
			if not _rows("biomes").is_empty():
				biome_id = str(_rows("biomes")[0].get("id", "yard"))
			creatures.append({
				"id": _unique_id("spirit", creatures),
				"name": "Новая нечисть",
				"biome": biome_id,
				"rarity": "common",
				"weight": 10,
				"income_scale": 1,
				"shape": "blob",
				"color": "#888888",
				"line": "",
			})
			_index = creatures.size() - 1
		4:
			var items := _rows("items")
			items.append({
				"id": _unique_id("item", items),
				"name": "Новый снаряд",
				"price": 100,
				"throw_mult": 1.2,
				"lure": 0,
				"color": "#8a4b32",
				"blurb": "",
			})
			_index = items.size() - 1
		5:
			var upgrades := _rows("upgrades")
			upgrades.append({
				"id": _unique_id("upgrade", upgrades),
				"name": "Новая покупка",
				"max_level": 5,
				"base_cost": 100,
				"growth": 1.5,
				"blurb": "Эффект есть только у throw_power, pen_slots, pen_income и lure.",
			})
			_index = upgrades.size() - 1
	_fill()


func _delete_entry() -> void:
	_flush_id()
	match _section:
		1:
			var ids := _rarity_ids()
			if ids.size() <= 1 or _index >= ids.size():
				return
			var rarity_id := str(ids[_index])
			if rarity_id == "common":
				set_status("Частую редкость лучше оставить: на неё опирается старт.")
				return
			for creature in _rows("creatures"):
				if str(creature.get("rarity", "")) == rarity_id:
					creature.rarity = "common"
			_balance().rarity.erase(rarity_id)
			_balance().sim.catch_rate.erase(rarity_id)
		2:
			var biomes := _rows("biomes")
			if biomes.size() <= 1 or _index >= biomes.size():
				return
			if float(biomes[_index].get("unlock_distance", 1)) <= 0.0:
				set_status("Стартовый край не удаляю.")
				return
			var dropped := str(biomes[_index].get("id", ""))
			var fallback := str(biomes[0].get("id", ""))
			biomes.remove_at(_index)
			for creature in _rows("creatures"):
				if str(creature.get("biome", "")) == dropped:
					creature.biome = fallback
		3:
			var creatures := _rows("creatures")
			if creatures.size() <= 1 or _index >= creatures.size():
				return
			creatures.remove_at(_index)
		4:
			var items := _rows("items")
			if items.size() <= 1 or _index >= items.size():
				return
			if int(items[_index].get("price", 0)) <= 0:
				set_status("Бесплатный стартовый снаряд не удаляю.")
				return
			items.remove_at(_index)
		5:
			var upgrades := _rows("upgrades")
			if _index >= upgrades.size():
				return
			upgrades.remove_at(_index)
	_index = maxi(0, _index - 1)
	_fill()


func _flush_id() -> void:
	if _id_line == null or not is_instance_valid(_id_line):
		return
	var text := _id_line.text.strip_edges()
	if str(_id_owner.get("kind", "")) == "rarity":
		_rename_rarity(str(_id_owner.get("id", "")), text)
		return
	if _id_owner.is_empty():
		return
	var old := str(_id_owner.get("id", ""))
	if text == "" or text == old:
		return
	if _id_taken(text):
		set_status("Такой id уже есть.")
		return
	_id_owner.id = text
	if _section == 2:
		for creature in _rows("creatures"):
			if str(creature.get("biome", "")) == old:
				creature.biome = text
	_refresh_list_label()


func _rename_rarity(old_id: String, new_id: String) -> void:
	if old_id == "" or new_id == "" or new_id == old_id:
		return
	var table: Dictionary = _balance().rarity
	if not table.has(old_id) or table.has(new_id):
		set_status("Редкость с таким id уже есть или старая пропала.")
		return
	table[new_id] = table[old_id]
	table.erase(old_id)
	for creature in _rows("creatures"):
		if str(creature.get("rarity", "")) == old_id:
			creature.rarity = new_id
	var rates: Dictionary = _balance().sim.catch_rate
	if rates.has(old_id):
		rates[new_id] = rates[old_id]
		rates.erase(old_id)
	_id_owner = {"kind": "rarity", "id": new_id}


func _current_row() -> Dictionary:
	var rows := _entries()
	if rows.is_empty() or _section == 1:
		return {}
	_index = clampi(_index, 0, rows.size() - 1)
	var row = rows[_index]
	if typeof(row) != TYPE_DICTIONARY:
		return {}
	return row


func _current_rarity_id() -> String:
	var ids := _rarity_ids()
	if ids.is_empty():
		return ""
	_index = clampi(_index, 0, ids.size() - 1)
	return str(ids[_index])


func _refresh_list_label() -> void:
	if _list == null or _section == 0:
		return
	var entries := _entries()
	if _index < 0 or _index >= entries.size() or _index >= _list.item_count:
		return
	_list.set_item_text(_index, _entry_label(entries[_index]))


func _id_taken(id: String) -> bool:
	var rows := _entries()
	for i in rows.size():
		if i == _index:
			continue
		var row = rows[i]
		if typeof(row) == TYPE_DICTIONARY and str(row.get("id", "")) == id:
			return true
	return false


func _choice_ids(rows: Array) -> Array:
	var ids: Array = []
	for row in rows:
		ids.append(str(row.get("id", "")))
	return ids


func _rarity_ids() -> Array:
	var ids: Array = []
	var table: Dictionary = _balance().get("rarity", {})
	for rarity_id in RARITY_ORDER:
		if table.has(rarity_id):
			ids.append(rarity_id)
	for rarity_id in table.keys():
		if not ids.has(str(rarity_id)):
			ids.append(str(rarity_id))
	return ids


func _rows(key: String) -> Array:
	var file: Dictionary = _bundle.get(key, {})
	var rows = file.get(key, [])
	if typeof(rows) != TYPE_ARRAY:
		rows = []
		file[key] = rows
		_bundle[key] = file
	return rows


func _balance() -> Dictionary:
	return _bundle.get("balance", {})


func _ensure_shape() -> void:
	if typeof(_bundle.get("balance")) != TYPE_DICTIONARY:
		_bundle.balance = {}
	if typeof(_bundle.balance.get("rarity")) != TYPE_DICTIONARY:
		_bundle.balance.rarity = {}
	if typeof(_bundle.balance.get("sim")) != TYPE_DICTIONARY:
		_bundle.balance.sim = {}
	if typeof(_bundle.balance.sim.get("catch_rate")) != TYPE_DICTIONARY:
		_bundle.balance.sim.catch_rate = {}
	for key in ["biomes", "creatures", "items", "upgrades"]:
		if typeof(_bundle.get(key)) != TYPE_DICTIONARY:
			_bundle[key] = {}
		if typeof(_bundle[key].get(key)) != TYPE_ARRAY:
			_bundle[key][key] = []


func _unique_id(base: String, rows: Array) -> String:
	var taken: Array = []
	for row in rows:
		taken.append(str(row.get("id", "")))
	return _unique_against(base, taken)


func _unique_key(base: String, table: Dictionary) -> String:
	return _unique_against(base, table.keys())


func _unique_against(base: String, taken: Array) -> String:
	if not taken.has(base):
		return base
	var number := 2
	while taken.has("%s_%d" % [base, number]):
		number += 1
	return "%s_%d" % [base, number]


func _clear(node: Node) -> void:
	while node.get_child_count() > 0:
		var child := node.get_child(0)
		node.remove_child(child)
		child.free()


func _caption(parent: Node, text: String) -> void:
	parent.add_child(_caption_label(text))


func _caption_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", ThrowTheme.MUTED if not dense else Color(0.75, 0.75, 0.75))
	label.add_theme_font_size_override("font_size", _font() - 2)
	return label


func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", _font())
	button.custom_minimum_size = Vector2(0, _control_h())
	return button


func _font() -> int:
	return 15 if dense else 20


func _control_h() -> int:
	return 32 if dense else 48

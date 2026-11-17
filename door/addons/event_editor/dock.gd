@tool
extends Control
## Док редактора: список событий, основные поля и сырой JSON одного события.

const PATH := "res://data/events.json"
const STATS: PackedStringArray = ["food", "health", "sanity", "ammo"]

var data: Dictionary = {}
var index: int = -1
var list: ItemList
var status: Label
var id_edit: LineEdit
var scene_edit: LineEdit
var image_edit: LineEdit
var weight_spin: SpinBox
var min_spin: SpinBox
var max_spin: SpinBox
var once_box: CheckBox
var priority_box: CheckBox
var flags_all: LineEdit
var flags_none: LineEdit
var setup_edit: TextEdit
var raw_edit: TextEdit
var branches: Dictionary = {}
var lock := false


func _ready() -> void:
	name = "События"
	custom_minimum_size = Vector2(360, 0)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	scroll.add_child(box)

	var bar := HBoxContainer.new()
	var reload := Button.new()
	reload.text = "Перечитать"
	reload.pressed.connect(_load_file)
	var save := Button.new()
	save.text = "Сохранить файл"
	save.pressed.connect(_save_file)
	bar.add_child(reload)
	bar.add_child(save)
	box.add_child(bar)

	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(status)

	list = ItemList.new()
	list.custom_minimum_size = Vector2(0, 160)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.item_selected.connect(func(i: int) -> void:
		if lock:
			return
		_apply_form()
		index = i
		_load_form()
	)
	box.add_child(list)

	id_edit = _line(box, "id")
	scene_edit = _line(box, "scene: door, dog, basement…")
	image_edit = _line(box, "image: пусто = scenes/<scene>, или свой файл в art/")
	var row := HBoxContainer.new()
	weight_spin = _spin(1, 200)
	min_spin = _spin(1, 60)
	max_spin = _spin(1, 60)
	row.add_child(_caption("вес"))
	row.add_child(weight_spin)
	row.add_child(_caption("с дня"))
	row.add_child(min_spin)
	row.add_child(_caption("по день"))
	row.add_child(max_spin)
	box.add_child(row)
	once_box = CheckBox.new()
	once_box.text = "один раз за забег"
	priority_box = CheckBox.new()
	priority_box.text = "приоритет, если подошло по дню"
	box.add_child(once_box)
	box.add_child(priority_box)
	flags_all = _line(box, "нужные флаги через запятую")
	flags_none = _line(box, "запретные флаги через запятую")
	setup_edit = _area(box, "Ситуация", 90)

	for which in ["a", "b"]:
		box.add_child(_caption("Выбор %s" % which.to_upper()))
		var label_edit := _line(box, "подпись кнопки")
		var text_edit := _area(box, "исход", 70)
		var kill := CheckBox.new()
		kill.text = "сразу смерть"
		box.add_child(kill)
		var death_title := _line(box, "заголовок карточки смерти")
		var death_line := _line(box, "строка карточки смерти")
		var sets := _line(box, "поставить флаги")
		var clears := _line(box, "снять флаги")
		var spins := {}
		var spin_row := HBoxContainer.new()
		for stat_id in STATS:
			var spin := _spin(-9, 9)
			spin.prefix = stat_id.substr(0, 1)
			spin_row.add_child(spin)
			spins[stat_id] = spin
		box.add_child(spin_row)
		branches[which] = {
			"label": label_edit,
			"text": text_edit,
			"kill": kill,
			"death_title": death_title,
			"death_line": death_line,
			"set_flags": sets,
			"clear_flags": clears,
			"spins": spins,
		}

	box.add_child(_caption("Сырой JSON события. Кнопка ниже заменяет событие целиком."))
	raw_edit = TextEdit.new()
	raw_edit.custom_minimum_size = Vector2(0, 180)
	raw_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	raw_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	box.add_child(raw_edit)
	var raw_btn := Button.new()
	raw_btn.text = "Применить JSON"
	raw_btn.pressed.connect(_apply_raw)
	box.add_child(raw_btn)

	var tools := HBoxContainer.new()
	var add := Button.new()
	add.text = "Новое"
	add.pressed.connect(_add)
	var dup := Button.new()
	dup.text = "Дублировать"
	dup.pressed.connect(_duplicate)
	var remove := Button.new()
	remove.text = "Удалить"
	remove.pressed.connect(_delete)
	tools.add_child(add)
	tools.add_child(dup)
	tools.add_child(remove)
	box.add_child(tools)
	_load_file()


func _load_file() -> void:
	var text := FileAccess.get_file_as_string(PATH)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		status.text = "Не читается data/events.json"
		data = {"version": 1, "meta": {}, "events": []}
		return
	data = parsed
	if typeof(data.get("events")) != TYPE_ARRAY:
		data["events"] = []
	_refresh_list()
	status.text = "Событий: %d" % data["events"].size()


func _refresh_list() -> void:
	lock = true
	list.clear()
	for ev in data["events"]:
		list.add_item(str(ev.get("id", "?")) if typeof(ev) == TYPE_DICTIONARY else "?")
	if data["events"].is_empty():
		index = -1
		lock = false
		return
	index = clampi(index, 0, data["events"].size() - 1)
	list.select(index)
	lock = false
	_load_form()


func _current() -> Dictionary:
	var events: Array = data.get("events", [])
	if index < 0 or index >= events.size() or typeof(events[index]) != TYPE_DICTIONARY:
		return {}
	return events[index]


func _load_form() -> void:
	var ev := _current()
	if ev.is_empty():
		return
	id_edit.text = str(ev.get("id", ""))
	scene_edit.text = str(ev.get("scene", "quiet"))
	image_edit.text = str(ev.get("image", ""))
	weight_spin.value = int(ev.get("weight", 1))
	once_box.button_pressed = bool(ev.get("once", true))
	priority_box.button_pressed = bool(ev.get("priority", false))
	var when: Dictionary = ev.get("when", {})
	min_spin.value = int(when.get("min_day", 1))
	max_spin.value = int(when.get("max_day", 30))
	flags_all.text = _join(when.get("flags_all", []))
	flags_none.text = _join(when.get("flags_none", []))
	setup_edit.text = str(ev.get("setup", ""))
	for which in ["a", "b"]:
		var branch: Dictionary = ev.get(which, {})
		var ui: Dictionary = branches[which]
		ui["label"].text = str(branch.get("label", ""))
		ui["text"].text = str(branch.get("text", ""))
		ui["kill"].button_pressed = bool(branch.get("kill", false))
		ui["death_title"].text = str(branch.get("death_title", ""))
		ui["death_line"].text = str(branch.get("death_line", ""))
		ui["set_flags"].text = _join(branch.get("set_flags", []))
		ui["clear_flags"].text = _join(branch.get("clear_flags", []))
		var effects: Dictionary = branch.get("effects", {})
		for stat_id in STATS:
			(ui["spins"][stat_id] as SpinBox).value = int(effects.get(stat_id, 0))
	raw_edit.text = JSON.stringify(ev, "\t")


func _apply_form() -> void:
	var ev := _current()
	if ev.is_empty():
		return
	var new_id := id_edit.text.strip_edges()
	if new_id == "":
		status.text = "Пустой id"
		return
	ev["id"] = new_id
	ev["scene"] = scene_edit.text.strip_edges()
	var picture := image_edit.text.strip_edges()
	if picture == "":
		ev.erase("image")
	else:
		ev["image"] = picture
	ev["weight"] = int(weight_spin.value)
	ev["once"] = once_box.button_pressed
	if priority_box.button_pressed:
		ev["priority"] = true
	else:
		ev.erase("priority")
	var when: Dictionary = ev.get("when", {})
	when["min_day"] = int(min_spin.value)
	when["max_day"] = int(max_spin.value)
	_put_list(when, "flags_all", flags_all.text)
	_put_list(when, "flags_none", flags_none.text)
	ev["when"] = when
	ev["setup"] = setup_edit.text
	for which in ["a", "b"]:
		if typeof(ev.get(which)) != TYPE_DICTIONARY:
			ev[which] = {}
		var branch: Dictionary = ev[which]
		var ui: Dictionary = branches[which]
		branch["label"] = ui["label"].text
		branch["text"] = ui["text"].text
		if ui["kill"].button_pressed:
			branch["kill"] = true
		else:
			branch.erase("kill")
		_put_text(branch, "death_title", ui["death_title"].text)
		_put_text(branch, "death_line", ui["death_line"].text)
		_put_list(branch, "set_flags", ui["set_flags"].text)
		_put_list(branch, "clear_flags", ui["clear_flags"].text)
		if not branch.has("roll"):
			var effects := {}
			for stat_id in STATS:
				var value := int((ui["spins"][stat_id] as SpinBox).value)
				if value != 0:
					effects[stat_id] = value
			if effects.is_empty():
				branch.erase("effects")
			else:
				branch["effects"] = effects
	if index >= 0 and index < list.item_count:
		list.set_item_text(index, new_id)
	raw_edit.text = JSON.stringify(ev, "\t")


func _apply_raw() -> void:
	var parsed: Variant = JSON.parse_string(raw_edit.text)
	if typeof(parsed) != TYPE_DICTIONARY or str(parsed.get("id", "")) == "":
		status.text = "JSON события не разобрался или нет id"
		return
	var events: Array = data["events"]
	if index < 0 or index >= events.size():
		return
	events[index] = parsed
	_load_form()
	status.text = "JSON применён в памяти. Нажми «Сохранить файл»."


func _save_file() -> void:
	_apply_form()
	var ids := {}
	for ev in data.get("events", []):
		if typeof(ev) != TYPE_DICTIONARY:
			status.text = "В списке есть не-объект"
			return
		var id := str(ev.get("id", ""))
		if id == "" or ids.has(id):
			status.text = "Повторяется или пустой id: %s" % id
			return
		if not ev.has("a") or not ev.has("b"):
			status.text = "%s без выбора a или b" % id
			return
		ids[id] = true
	var text := JSON.stringify(data, "\t")
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		status.text = "Не записал файл: %s" % error_string(FileAccess.get_open_error())
		return
	file.store_string(text)
	file.store_string("\n")
	file.close()
	status.text = "Сохранено: data/events.json (%d)" % ids.size()


func _add() -> void:
	_apply_form()
	var events: Array = data["events"]
	var n := events.size() + 1
	var id := "event_%d" % n
	events.append(_template(id))
	index = events.size() - 1
	_refresh_list()


func _duplicate() -> void:
	_apply_form()
	var ev := _current()
	if ev.is_empty():
		return
	var copy: Dictionary = JSON.parse_string(JSON.stringify(ev))
	copy["id"] = str(copy.get("id", "event")) + "_copy"
	data["events"].append(copy)
	index = data["events"].size() - 1
	_refresh_list()


func _delete() -> void:
	var events: Array = data.get("events", [])
	if index < 0 or index >= events.size():
		return
	events.remove_at(index)
	index = mini(index, events.size() - 1)
	_refresh_list()
	status.text = "Удалено из памяти. Сохрани файл, если так и надо."


func _template(id: String) -> Dictionary:
	return {
		"id": id,
		"once": true,
		"weight": 1,
		"scene": "door",
		"when": {"min_day": 1, "max_day": 30},
		"setup": "Новая ситуация.",
		"a": {"label": "Да", "text": "Ты согласился.", "effects": {"sanity": -1}},
		"b": {"label": "Нет", "text": "Ты отказался.", "effects": {"sanity": 1}},
	}


func _line(parent: Node, placeholder: String) -> LineEdit:
	var edit := LineEdit.new()
	edit.placeholder_text = placeholder
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(edit)
	return edit


func _area(parent: Node, title: String, height: float) -> TextEdit:
	parent.add_child(_caption(title))
	var edit := TextEdit.new()
	edit.custom_minimum_size = Vector2(0, height)
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	parent.add_child(edit)
	return edit


func _spin(from: float, to: float) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = from
	spin.max_value = to
	spin.step = 1
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return spin


func _caption(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label


func _join(value: Variant) -> String:
	if typeof(value) != TYPE_ARRAY:
		return ""
	var parts: PackedStringArray = []
	for item in value:
		parts.append(str(item))
	return ", ".join(parts)


func _split_list(text: String) -> Array:
	var out: Array = []
	for part in text.split(",", false):
		var item := part.strip_edges()
		if item != "":
			out.append(item)
	return out


func _put_list(target: Dictionary, key: String, text: String) -> void:
	var items := _split_list(text)
	if items.is_empty():
		target.erase(key)
	else:
		target[key] = items


func _put_text(target: Dictionary, key: String, text: String) -> void:
	var clean := text.strip_edges()
	if clean == "":
		target.erase(key)
	else:
		target[key] = clean

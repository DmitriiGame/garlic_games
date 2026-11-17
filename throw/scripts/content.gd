extends Node
## Каталог игры. В редакторе всегда data/, в сборке user:// перекрывает встроенные файлы.

var balance: Dictionary = {}
var biomes: Array = []
var creatures: Array = []
var items: Array = []
var upgrades: Array = []
var biome_by_id: Dictionary = {}
var creature_by_id: Dictionary = {}
var item_by_id: Dictionary = {}
var upgrade_by_id: Dictionary = {}
var problems: Array[String] = []


func _ready() -> void:
	load_all()


func load_all() -> bool:
	problems.clear()
	var raw := {}
	for entry in DataFiles.NAMES:
		raw[entry] = _read_named(entry)
	balance = raw.balance
	biomes = _array_of(raw.biomes, "biomes")
	creatures = _array_of(raw.creatures, "creatures")
	items = _array_of(raw.items, "items")
	upgrades = _array_of(raw.upgrades, "upgrades")
	biomes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("unlock_distance", 0)) < float(b.get("unlock_distance", 0))
	)
	_index()
	_validate()
	return problems.is_empty()


func bundle() -> Dictionary:
	return {
		"balance": balance.duplicate(true),
		"biomes": {"version": 1, "biomes": biomes.duplicate(true)},
		"creatures": {"version": 1, "creatures": creatures.duplicate(true)},
		"items": {"version": 1, "items": items.duplicate(true)},
		"upgrades": {"version": 1, "upgrades": upgrades.duplicate(true)},
	}


func save_all(next_bundle: Dictionary) -> String:
	var editor := OS.has_feature("editor")
	for entry in DataFiles.NAMES:
		if typeof(next_bundle.get(entry)) != TYPE_DICTIONARY:
			return "нет раздела %s" % entry
		var path := DataFiles.res_path(entry) if editor else DataFiles.user_path(entry)
		var err := DataFiles.write_text(path, next_bundle[entry])
		if err != OK:
			return "запись не удалась: %s (%s)" % [entry, error_string(err)]
	load_all()
	if editor:
		return "записано в data/"
	return "записано в user://"


func clear_overrides() -> void:
	for entry in DataFiles.NAMES:
		var path := DataFiles.user_path(entry)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	load_all()


func source_label() -> String:
	if OS.has_feature("editor"):
		return "сейчас пишется в data/ (открыт редактор Godot)"
	for entry in DataFiles.NAMES:
		if FileAccess.file_exists(DataFiles.user_path(entry)):
			return "сейчас пишется в user/ и перекрывает встроенные числа"
	return "в сборке запись ляжет в user/ и перекроет встроенные числа"


func rarity(id: String) -> Dictionary:
	var table: Dictionary = balance.get("rarity", {})
	var row = table.get(id, {})
	if typeof(row) != TYPE_DICTIONARY:
		return {}
	return row


func rarity_label(id: String) -> String:
	var row := rarity(id)
	var label := str(row.get("label", "")).strip_edges()
	return label if label != "" else id


func _read_named(entry: String) -> Dictionary:
	var path := _active_path(entry)
	var parsed: Variant = {}
	if FileAccess.file_exists(path):
		parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY and path != DataFiles.res_path(entry):
		problems.append("%s: битый user://, беру data/" % entry)
		parsed = JSON.parse_string(FileAccess.get_file_as_string(DataFiles.res_path(entry)))
	if typeof(parsed) != TYPE_DICTIONARY:
		problems.append("%s не читается" % entry)
		return {}
	return parsed


func _active_path(entry: String) -> String:
	if OS.has_feature("editor"):
		return DataFiles.res_path(entry)
	var user_path := DataFiles.user_path(entry)
	if FileAccess.file_exists(user_path):
		return user_path
	return DataFiles.res_path(entry)


func _array_of(file_data: Dictionary, key: String) -> Array:
	var value: Variant = file_data.get(key, [])
	if typeof(value) != TYPE_ARRAY:
		problems.append("%s: ждал список" % key)
		return []
	var clean: Array = []
	for item in value:
		if typeof(item) == TYPE_DICTIONARY:
			clean.append(item)
		else:
			problems.append("%s: элемент не объект" % key)
	return clean


func _index() -> void:
	biome_by_id.clear()
	creature_by_id.clear()
	item_by_id.clear()
	upgrade_by_id.clear()
	for biome in biomes:
		biome_by_id[str(biome.get("id", ""))] = biome
	for creature in creatures:
		creature_by_id[str(creature.get("id", ""))] = creature
	for item in items:
		item_by_id[str(item.get("id", ""))] = item
	for upgrade in upgrades:
		upgrade_by_id[str(upgrade.get("id", ""))] = upgrade


func _validate() -> void:
	_unique("край", biomes)
	_unique("нечисть", creatures)
	_unique("снаряд", items)
	_unique("улучшение", upgrades)
	if biomes.is_empty():
		problems.append("нет краёв")
	if creatures.is_empty():
		problems.append("нет нечисти")
	if items.is_empty():
		problems.append("нет снарядов")
	var seen_distance := {}
	for biome in biomes:
		var distance := float(biome.get("unlock_distance", 0))
		if seen_distance.has(distance):
			problems.append("два края на одной дальности %s" % distance)
		seen_distance[distance] = true
	var known_rarity: Dictionary = balance.get("rarity", {})
	if typeof(known_rarity) != TYPE_DICTIONARY or known_rarity.is_empty():
		problems.append("нет таблицы редкостей")
		known_rarity = {}
	var weight_by_biome := {}
	for creature in creatures:
		var id := str(creature.get("id", ""))
		var biome_id := str(creature.get("biome", ""))
		if not biome_by_id.has(biome_id):
			problems.append("%s ссылается на неизвестный край %s" % [id, biome_id])
		var rarity_id := str(creature.get("rarity", ""))
		if not known_rarity.has(rarity_id):
			problems.append("%s: неизвестная редкость %s" % [id, rarity_id])
		var weight := int(creature.get("weight", 0))
		if weight <= 0:
			problems.append("%s: вес должен быть больше нуля" % id)
		weight_by_biome[biome_id] = int(weight_by_biome.get(biome_id, 0)) + maxi(0, weight)
		var shape := str(creature.get("shape", "blob"))
		if shape not in ["blob", "squat", "tall", "horned", "wispy"]:
			problems.append("%s: фигура %s не из набора" % [id, shape])
	for biome in biomes:
		var biome_id := str(biome.get("id", ""))
		if int(weight_by_biome.get(biome_id, 0)) <= 0:
			problems.append("в крае %s некому появляться" % biome_id)
	for rarity_id in known_rarity.keys():
		var row = known_rarity[rarity_id]
		if typeof(row) != TYPE_DICTIONARY:
			problems.append("редкость %s сломана" % rarity_id)
			continue
		if float(row.get("window", 0)) <= 0.0:
			problems.append("редкость %s: окно ловли пустое" % rarity_id)
		if float(row.get("income", 0)) < 0.0:
			problems.append("редкость %s: доход отрицательный" % rarity_id)
	if int(balance.get("max_spawns", 1)) < int(balance.get("base_spawns", 1)):
		problems.append("потолок гостей меньше базового числа")
	if float(balance.get("power_distance", 0)) <= 0.0:
		problems.append("прибавка дальности должна быть больше нуля")
	var cap := int(balance.get("offline_cap_sec", 0))
	if cap < 60:
		problems.append("потолок оффлайна слишком мал")
	for upgrade in upgrades:
		if float(upgrade.get("growth", 0)) < 1.0:
			problems.append("%s: рост цены меньше 1" % upgrade.get("id", ""))
		if int(upgrade.get("max_level", 0)) <= 0:
			problems.append("%s: нет уровней" % upgrade.get("id", ""))


func _unique(kind: String, rows: Array) -> void:
	var seen := {}
	for row in rows:
		var id := str(row.get("id", ""))
		if id == "":
			problems.append("%s без id" % kind)
			continue
		if seen.has(id):
			problems.append("повтор id %s у %s" % [id, kind])
		seen[id] = true

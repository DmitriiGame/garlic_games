extends Node
## Забег на 30 дней. Все тексты, условия и эффекты читаются из data/events.json.

const RES_PATH := "res://data/events.json"
const USER_PATH := "user://events.json"
const STAT_ORDER: Array[String] = ["food", "health", "sanity", "ammo"]

var data: Dictionary = {}
var meta: Dictionary = {}
var events: Array = []
var by_id: Dictionary = {}

var day: int = 1
var days_to_win: int = 30
var stats: Dictionary = {}
var flags: Dictionary = {}
var flag_order: Array[String] = []
var seen: Dictionary = {}
var rng := RandomNumberGenerator.new()
var seed_value: int = 0
var pending: Dictionary = {}
var run_over: bool = false
var won: bool = false
var ending_title: String = ""
var ending_line: String = ""
var last_reveal: Dictionary = {}
var source_label: String = RES_PATH
var using_override: bool = false


func _ready() -> void:
	load_data()


func active_data_path() -> String:
	# В редакторе всегда файл проекта, чтобы плагин и плейтест не расходились.
	# В сборке user://events.json перекрывает файл, если игрок правил тексты.
	if OS.has_feature("editor"):
		return RES_PATH
	if FileAccess.file_exists(USER_PATH):
		return USER_PATH
	return RES_PATH


func load_data() -> bool:
	var path := active_data_path()
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty() and path != RES_PATH:
		text = FileAccess.get_file_as_string(RES_PATH)
		path = RES_PATH
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Откроешь дверь: не читается " + path)
		data = {}
		meta = {}
		events = []
		by_id = {}
		source_label = path
		return false
	data = parsed
	meta = data.get("meta", {})
	events = data.get("events", [])
	by_id.clear()
	var seen_ids := {}
	for ev in events:
		if typeof(ev) != TYPE_DICTIONARY:
			continue
		var id := str(ev.get("id", ""))
		if id == "" or seen_ids.has(id):
			push_error("Откроешь дверь: пустой или повторный id события")
			continue
		seen_ids[id] = true
		by_id[id] = ev
	days_to_win = int(meta.get("days_to_win", 30))
	source_label = path
	using_override = path == USER_PATH
	return true


func save_data(new_data: Dictionary) -> String:
	var text := JSON.stringify(new_data, "\t")
	if text.is_empty():
		return "не удалось собрать JSON"
	var target := RES_PATH if OS.has_feature("editor") else USER_PATH
	var err := _write_text(target, text)
	if err != OK:
		return "запись не удалась (%s)" % error_string(err)
	load_data()
	if target == RES_PATH:
		return "записано в data/events.json"
	return "записано в user://events.json"


func clear_override() -> void:
	if FileAccess.file_exists(USER_PATH):
		DirAccess.remove_absolute(USER_PATH)
	load_data()


func start_run(fixed_seed: int = -1) -> void:
	load_data()
	if fixed_seed >= 0:
		seed_value = fixed_seed
	else:
		seed_value = randi() % 1000000
	rng.seed = seed_value
	day = 1
	days_to_win = int(meta.get("days_to_win", 30))
	flags.clear()
	flag_order.clear()
	seen.clear()
	run_over = false
	won = false
	ending_title = ""
	ending_line = ""
	last_reveal = {}
	stats.clear()
	var spec: Dictionary = meta.get("stats", {})
	for id in STAT_ORDER:
		stats[id] = int(spec.get(id, {}).get("start", 0))
	var opening := str(meta.get("opening_event", ""))
	if opening != "" and by_id.has(opening) and _eligible(by_id[opening]):
		pending = by_id[opening]
	else:
		pending = _pick("")


func stat_label(id: String) -> String:
	return str(meta.get("stats", {}).get(id, {}).get("label", id))


func stat_max(id: String) -> int:
	return maxi(1, int(meta.get("stats", {}).get(id, {}).get("max", 1)))


func night_hint() -> String:
	return str(meta.get("night_hint", ""))


func epitaphs(limit: int = 4) -> Array[String]:
	var map: Dictionary = meta.get("epithets", {})
	var out: Array[String] = []
	for i in range(flag_order.size() - 1, -1, -1):
		var flag := flag_order[i]
		if flags.get(flag, false) and map.has(flag):
			out.append(str(map[flag]))
		if out.size() >= limit:
			break
	return out


func choice_view(which: String) -> Dictionary:
	var raw: Dictionary = pending.get(which, {})
	var needs: Dictionary = raw.get("needs", {})
	var missing: Array[String] = []
	for key in needs.keys():
		var stat_id := str(key)
		if int(stats.get(stat_id, 0)) < int(needs[key]):
			missing.append(stat_label(stat_id))
	var enabled := missing.is_empty() or raw.has("blocked")
	return {
		"label": str(raw.get("label", "…")),
		"enabled": enabled,
		"missing": missing,
	}


func choose(which: String) -> Dictionary:
	var event: Dictionary = pending
	var raw: Dictionary = event.get(which, {})
	var branch := _resolve_branch(raw)
	var event_id := str(event.get("id", ""))
	if event_id != "":
		seen[event_id] = true
	var deltas := _apply_effects(branch.get("effects", {}))
	var gained: Dictionary = deltas.duplicate()
	_apply_flags(branch)
	var notes: Array[String] = []
	var dead := bool(branch.get("kill", false))
	var cause := "kill" if dead else ""
	var title := str(branch.get("death_title", ""))
	var line := str(branch.get("death_line", ""))
	if not dead and int(stats.get("health", 0)) <= 0:
		dead = true
		cause = "health"
	elif not dead and int(stats.get("sanity", 0)) <= 0:
		dead = true
		cause = "sanity"
	if not dead:
		notes = _apply_upkeep(deltas, gained)
		if int(stats.get("health", 0)) <= 0:
			dead = true
			cause = "hunger"
		elif int(stats.get("sanity", 0)) <= 0:
			dead = true
			cause = "sanity"
	if dead:
		run_over = true
		won = false
		if title == "":
			match cause:
				"health":
					title = "Тело сдалось"
					line = "Здоровье кончилось раньше консервов."
				"sanity":
					title = "Ты вышел сам"
					line = "Рассудок открыл дверь изнутри."
				"hunger":
					title = "Голод не стучит"
					line = "Еда кончилась. Следом — ты."
				_:
					title = "Конец серии"
					line = _fill(str(branch.get("text", "")))
		ending_title = title
		ending_line = line if line != "" else _fill(str(branch.get("text", "")))
	elif day >= days_to_win:
		run_over = true
		won = true
		ending_title = str(meta.get("win_title", "Дверь осталась при тебе"))
		ending_line = str(meta.get("win_line", "Тридцать дней. Ты ещё дышишь."))
	else:
		day += 1
		pending = _pick(event_id)
	var bad := dead
	for key in deltas.keys():
		if int(deltas[key]) < 0:
			bad = true
	last_reveal = {
		"text": _fill(str(branch.get("text", ""))),
		"deltas": deltas,
		"notes": notes,
		"bad": bad,
		"dead": dead,
		"won": won,
		"event_id": event_id,
		"choice": which,
		"scene": str(event.get("scene", "quiet")),
		"image": illustration_path(event),
	}
	return last_reveal


func setup_text() -> String:
	return _fill(str(pending.get("setup", "…")))


func scene_id() -> String:
	return str(pending.get("scene", "quiet"))


func sound_key(event: Dictionary = {}) -> String:
	var source: Dictionary = event if not event.is_empty() else pending
	var named := str(source.get("sound", "")).strip_edges().replace("\\", "/")
	named = named.trim_prefix("res://audio/").trim_prefix("res://")
	for ext in [".ogg", ".wav"]:
		if named.ends_with(ext):
			named = named.trim_suffix(ext)
	if named == "":
		named = "scenes/%s" % str(source.get("scene", "quiet"))
	var path := "res://audio/%s.ogg" % named
	if ResourceLoader.exists(path) or FileAccess.file_exists(path):
		return named
	return "scenes/%s" % str(source.get("scene", "quiet"))


func illustration_path(event: Dictionary = {}) -> String:
	var source: Dictionary = event if not event.is_empty() else pending
	var named := str(source.get("image", "")).strip_edges().replace("\\", "/")
	named = named.trim_prefix("res://art/").trim_prefix("res://")
	if named == "":
		named = "scenes/%s" % str(source.get("scene", "quiet"))
	for ext in [".webp", ".jpg", ".jpeg", ".png"]:
		if named.ends_with(ext):
			named = named.trim_suffix(ext)
	var path := "res://art/%s.webp" % named
	if _resource_exists(path):
		return path
	var by_scene := "res://art/scenes/%s.webp" % str(source.get("scene", "quiet"))
	if _resource_exists(by_scene):
		return by_scene
	return "res://art/hero.webp"


func _resource_exists(path: String) -> bool:
	return ResourceLoader.exists(path) or FileAccess.file_exists(path)


func eligible_ids() -> Array[String]:
	var ids: Array[String] = []
	for ev in events:
		if typeof(ev) != TYPE_DICTIONARY:
			continue
		if _eligible(ev):
			ids.append(str(ev.get("id", "")))
	return ids


func _pick(avoid_id: String) -> Dictionary:
	var pool: Array[Dictionary] = []
	var total := 0
	var priority: Array[Dictionary] = []
	var priority_total := 0
	for ev in events:
		if typeof(ev) != TYPE_DICTIONARY:
			continue
		if not _eligible(ev):
			continue
		var weight := maxi(0, int(ev.get("weight", 1)))
		if weight <= 0:
			continue
		pool.append(ev)
		total += weight
		if bool(ev.get("priority", false)):
			priority.append(ev)
			priority_total += weight
	if pool.is_empty():
		return _fallback()
	if not priority.is_empty():
		pool = priority
		total = priority_total
	if avoid_id != "" and pool.size() > 1:
		var trimmed: Array[Dictionary] = []
		var trimmed_total := 0
		for ev in pool:
			if str(ev.get("id", "")) == avoid_id:
				continue
			trimmed.append(ev)
			trimmed_total += maxi(1, int(ev.get("weight", 1)))
		if not trimmed.is_empty():
			pool = trimmed
			total = trimmed_total
	var roll := rng.randi_range(1, maxi(1, total))
	var acc := 0
	for ev in pool:
		acc += maxi(1, int(ev.get("weight", 1)))
		if roll <= acc:
			return ev
	return pool[0]


func _eligible(ev: Dictionary) -> bool:
	if bool(ev.get("once", true)) and seen.has(str(ev.get("id", ""))):
		return false
	var cond: Dictionary = ev.get("when", {})
	if day < int(cond.get("min_day", 1)):
		return false
	if day > int(cond.get("max_day", 999)):
		return false
	for flag in cond.get("flags_all", []):
		if not flags.get(str(flag), false):
			return false
	for flag in cond.get("flags_none", []):
		if flags.get(str(flag), false):
			return false
	var any: Array = cond.get("flags_any", [])
	if not any.is_empty():
		var ok := false
		for flag in any:
			if flags.get(str(flag), false):
				ok = true
				break
		if not ok:
			return false
	for event_id in cond.get("seen_all", []):
		if not seen.has(str(event_id)):
			return false
	var stat_rules: Dictionary = cond.get("stats", {})
	for key in stat_rules.keys():
		var rule: Dictionary = stat_rules[key]
		var value := int(stats.get(str(key), 0))
		if rule.has("min") and value < int(rule["min"]):
			return false
		if rule.has("max") and value > int(rule["max"]):
			return false
	return true


func _resolve_branch(raw: Dictionary) -> Dictionary:
	var needs: Dictionary = raw.get("needs", {})
	for key in needs.keys():
		if int(stats.get(str(key), 0)) < int(needs[key]):
			if raw.has("blocked") and typeof(raw["blocked"]) == TYPE_DICTIONARY:
				return raw["blocked"]
			return raw
	var roll_list: Variant = raw.get("roll", [])
	if typeof(roll_list) == TYPE_ARRAY and not (roll_list as Array).is_empty():
		var entries: Array = roll_list
		var total := 0
		for entry in entries:
			if typeof(entry) == TYPE_DICTIONARY:
				total += maxi(1, int(entry.get("w", 1)))
		if total > 0:
			var roll := rng.randi_range(1, total)
			var acc := 0
			for entry in entries:
				if typeof(entry) != TYPE_DICTIONARY:
					continue
				acc += maxi(1, int(entry.get("w", 1)))
				if roll <= acc:
					return entry
	return raw


func _apply_effects(effects: Variant) -> Dictionary:
	var deltas := {}
	if typeof(effects) != TYPE_DICTIONARY:
		return deltas
	for key in effects.keys():
		var stat_id := str(key)
		if not stats.has(stat_id):
			continue
		var before := int(stats[stat_id])
		var after := clampi(before + int(effects[key]), 0, stat_max(stat_id))
		stats[stat_id] = after
		deltas[stat_id] = after - before
	return deltas


func _apply_upkeep(deltas: Dictionary, gained: Dictionary) -> Array[String]:
	var notes: Array[String] = []
	var upkeep: Dictionary = meta.get("upkeep", {})
	var skip: Array = meta.get("upkeep_skip_if_gained", [])
	for key in upkeep.keys():
		var stat_id := str(key)
		if not stats.has(stat_id):
			continue
		if skip.has(stat_id) and int(gained.get(stat_id, 0)) > 0:
			continue
		var before := int(stats[stat_id])
		var want := before + int(upkeep[key])
		if want < 0:
			stats[stat_id] = 0
			var starve: Dictionary = meta.get("starve", {})
			if str(starve.get("when", "")) == stat_id:
				var damage: Dictionary = starve.get("damage", {})
				for dkey in damage.keys():
					var did := str(dkey)
					if not stats.has(did):
						continue
					var dbefore := int(stats[did])
					var dafter := clampi(dbefore + int(damage[dkey]), 0, stat_max(did))
					stats[did] = dafter
					deltas[did] = int(deltas.get(did, 0)) + (dafter - dbefore)
				notes.append(str(starve.get("line", "Голод.")))
		else:
			stats[stat_id] = mini(want, stat_max(stat_id))
		deltas[stat_id] = int(deltas.get(stat_id, 0)) + (int(stats[stat_id]) - before)
	return notes


func _apply_flags(branch: Dictionary) -> void:
	for flag in branch.get("set_flags", []):
		_set_flag(str(flag))
	for flag in branch.get("clear_flags", []):
		var name := str(flag)
		flags.erase(name)
		flag_order.erase(name)


func _set_flag(flag: String) -> void:
	if flag == "":
		return
	flags[flag] = true
	flag_order.erase(flag)
	flag_order.append(flag)


func _fill(text: String) -> String:
	var filled := text.replace("{day}", str(day))
	for id in STAT_ORDER:
		filled = filled.replace("{%s}" % id, str(int(stats.get(id, 0))))
	return filled


func _fallback() -> Dictionary:
	return {
		"id": "_quiet_fallback",
		"once": false,
		"scene": "quiet",
		"setup": "Тишина давит на дверь изнутри. Даже крысы сегодня заняты.",
		"a": {
			"label": "Поспать",
			"text": "Сон короткий и злой. Утром ты всё ещё тут.",
			"effects": {"sanity": 1},
		},
		"b": {
			"label": "Скрести шкаф",
			"text": "Крошки, пыль и гордость. Две из трёх съедобны условно.",
			"effects": {"food": 1, "sanity": -1},
		},
	}


func _write_text(path: String, text: String) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(text)
	file.close()
	return OK

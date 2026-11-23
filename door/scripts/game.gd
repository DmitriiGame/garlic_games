extends Node
## Три главы по 30 дней. Тексты, условия и эффекты читаются из data/events.json.

const RES_PATH := "res://data/events.json"
const USER_PATH := "user://events.json"
const CHECKPOINT_PATH := "user://chapter_checkpoint.json"
const META_PATH := "user://meta.cfg"
const WEAPON_ORDER: Array[String] = ["baguette", "pan", "crowbar", "rifle"]
const STAT_ORDER: Array[String] = ["food", "health", "sanity", "ammo"]
const KNOWN_SCENES: Array[String] = [
	"door", "open", "basement", "window", "stranger", "radio", "dog", "street",
	"mirror", "kid", "horde", "gun", "letter", "food", "cult", "soldier", "quiet",
	"roof_tent", "roof_rain", "rooftops", "drone", "pigeon", "stairs_up",
	"road", "camp", "car", "dacha", "wedding",
]
## Новые локации пока без своих рисунков: одна карта на все фоллбэки.
const SCENE_ART_FALLBACK := {
	"roof_tent": "window",
	"roof_rain": "street",
	"rooftops": "street",
	"drone": "radio",
	"pigeon": "window",
	"stairs_up": "door",
	"road": "street",
	"camp": "soldier",
	"car": "street",
	"dacha": "food",
	"wedding": "cult",
}

var data: Dictionary = {}
var meta: Dictionary = {}
var events: Array = []
var by_id: Dictionary = {}

var day: int = 1
var chapter: int = 1
var chapter_days: int = 30
var days_to_win: int = 90
var chapter_break: bool = false
var chapter_report: Dictionary = {}
var last_highlight: bool = false
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
var awaiting_battle: bool = false
var battle = null
var _battle_pack: Dictionary = {}
var weapon: String = "baguette"
var best_weapon: String = "baguette"
var artifacts: Array[String] = []
var flat_medal: bool = false
var bonus_max_hp: int = 0


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
	days_to_win = int(meta.get("days_to_win", 90))
	chapter_days = int(meta.get("days_per_chapter", 30))
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
	_load_meta()
	weapon = best_weapon
	artifacts.clear()
	_recompute_bonus()
	awaiting_battle = false
	battle = null
	day = 1
	chapter = 1
	chapter_break = false
	chapter_report = {}
	last_highlight = false
	days_to_win = int(meta.get("days_to_win", 90))
	chapter_days = int(meta.get("days_per_chapter", 30))
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
	if flat_medal:
		stats["health"] = stat_max("health")
	pending = _opening_or_pick(1)
	save_checkpoint()


func stat_label(id: String) -> String:
	return str(meta.get("stats", {}).get(id, {}).get("label", id))


func stat_max(id: String) -> int:
	var base := maxi(1, int(meta.get("stats", {}).get(id, {}).get("max", 1)))
	if id == "health":
		base += bonus_max_hp
	return base


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
		seen[event_id] = int(seen.get(event_id, 0)) + 1
	last_highlight = bool(event.get("highlight", false))
	var fight: Variant = branch.get("battle", event.get("battle", {}))
	if typeof(fight) == TYPE_DICTIONARY and not (fight as Dictionary).is_empty():
		_battle_pack = {"branch": branch, "event": event, "event_id": event_id, "spec": fight, "choice": which}
		awaiting_battle = true
		battle = preload("res://scripts/battle.gd").new()
		battle.start(self, fight)
		last_reveal = {
			"text": _fill(str(event.get("setup", ""))),
			"deltas": {},
			"notes": [],
			"bad": false,
			"dead": false,
			"won": false,
			"battle": true,
			"event_id": event_id,
			"choice": which,
			"scene": str(event.get("scene", "quiet")),
			"image": illustration_path(event),
			"highlight": last_highlight,
			"chapter_break": false,
		}
		return last_reveal
	return _conclude(branch, event, event_id, which)


func finish_battle(victory: bool) -> Dictionary:
	var pack: Dictionary = _battle_pack
	awaiting_battle = false
	if not victory:
		stats["health"] = 0
		run_over = true
		won = false
		ending_title = "Вас добили"
		ending_line = str(battle.log_line) if battle else "Бой кончился плохо."
		last_reveal = {
			"text": ending_line,
			"deltas": {"health": -int(stat_max("health"))},
			"notes": [],
			"bad": true,
			"dead": true,
			"won": false,
			"battle": false,
			"event_id": str(pack.get("event_id", "")),
			"choice": "",
			"scene": str(pack.get("event", {}).get("scene", "quiet")),
			"image": illustration_path(pack.get("event", {})),
			"highlight": false,
			"chapter_break": false,
		}
		battle = null
		return last_reveal
	var branch: Dictionary = (pack["branch"] as Dictionary).duplicate(true)
	var spec: Dictionary = pack["spec"]
	var effects: Dictionary = branch.get("effects", {}).duplicate(true)
	var reward: Dictionary = spec.get("reward", {})
	for key in reward.keys():
		effects[str(key)] = int(effects.get(key, 0)) + int(reward[key])
	if effects.is_empty():
		branch.erase("effects")
	else:
		branch["effects"] = effects
	var found := str(spec.get("weapon", ""))
	if found != "":
		grant_weapon(found)
	_maybe_artifact()
	battle = null
	return _conclude(branch, pack["event"], str(pack["event_id"]), str(pack.get("choice", "")))


func _conclude(branch: Dictionary, event: Dictionary, event_id: String, which: String) -> Dictionary:
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
	elif day >= chapter_days:
		if chapter >= _chapter_count():
			run_over = true
			won = true
			ending_title = str(meta.get("win_title", "Три адреса"))
			ending_line = str(meta.get("win_line", "Девяносто дней. Вы ещё дышите."))
		else:
			_mark_chapter_break()
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
		"highlight": last_highlight,
		"chapter_break": chapter_break,
	}
	return last_reveal


func setup_text() -> String:
	return _fill(str(pending.get("setup", "…")))


func scene_id() -> String:
	return str(pending.get("scene", "quiet"))


func is_highlight() -> bool:
	return bool(pending.get("highlight", false))


func chapter_title(number: int = -1) -> String:
	var info := _chapter_info(chapter if number < 0 else number)
	var name := str(info.get("name", ""))
	return name if name != "" else "Глава"


func total_day() -> int:
	return (chapter - 1) * chapter_days + day


func header_text() -> String:
	return "Глава %d · %s · День %02d" % [chapter, chapter_title(), day]


func sound_key(event: Dictionary = {}) -> String:
	var source: Dictionary = event if not event.is_empty() else pending
	var named := str(source.get("sound", "")).strip_edges().replace("\\", "/")
	named = named.trim_prefix("res://audio/").trim_prefix("res://")
	for ext in [".ogg", ".wav"]:
		if named.ends_with(ext):
			named = named.trim_suffix(ext)
	var scene_name := str(source.get("scene", "quiet"))
	if named == "":
		named = "scenes/%s" % scene_name
	var path := "res://audio/%s.ogg" % named
	if ResourceLoader.exists(path) or FileAccess.file_exists(path):
		return named
	var mapped := str(SCENE_ART_FALLBACK.get(scene_name, ""))
	if mapped != "":
		var fallback := "res://audio/scenes/%s.ogg" % mapped
		if ResourceLoader.exists(fallback) or FileAccess.file_exists(fallback):
			return "scenes/%s" % mapped
	return "scenes/%s" % scene_name


func illustration_path(event: Dictionary = {}) -> String:
	var source: Dictionary = event if not event.is_empty() else pending
	var named := str(source.get("image", "")).strip_edges().replace("\\", "/")
	named = named.trim_prefix("res://art/").trim_prefix("res://")
	if named == "":
		named = "scenes/%s" % str(source.get("scene", "quiet"))
	for ext in [".webp", ".jpg", ".jpeg", ".png"]:
		if named.ends_with(ext):
			named = named.trim_suffix(ext)
	var scene_name := str(source.get("scene", "quiet"))
	var path := "res://art/%s.webp" % named
	if _resource_exists(path):
		return path
	var by_scene := "res://art/scenes/%s.webp" % scene_name
	if _resource_exists(by_scene):
		return by_scene
	var mapped := str(SCENE_ART_FALLBACK.get(scene_name, ""))
	if mapped != "":
		var fallback := "res://art/scenes/%s.webp" % mapped
		if _resource_exists(fallback):
			return fallback
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
	if day >= chapter_days:
		var finale := _finale_event()
		if not finale.is_empty():
			return finale
	var pool: Array[Dictionary] = []
	var total := 0
	var priority: Array[Dictionary] = []
	var priority_total := 0
	for ev in events:
		if typeof(ev) != TYPE_DICTIONARY:
			continue
		if not _eligible(ev):
			continue
		var weight := _weight_of(ev)
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
			trimmed_total += maxi(1, _weight_of(ev))
		if not trimmed.is_empty():
			pool = trimmed
			total = trimmed_total
	var roll := rng.randi_range(1, maxi(1, total))
	var acc := 0
	for ev in pool:
		acc += maxi(1, _weight_of(ev))
		if roll <= acc:
			return ev
	return pool[0]


func _eligible(ev: Dictionary) -> bool:
	var event_id := str(ev.get("id", ""))
	var times := int(seen.get(event_id, 0))
	var cap := 1 if bool(ev.get("once", true)) else int(ev.get("max_times", 3))
	if times >= cap:
		return false
	if _chapter_of(ev) != chapter:
		return false
	var cond: Dictionary = ev.get("when", {})
	if cond.has("chapter") and int(cond.get("chapter", chapter)) != chapter:
		return false
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
	for prior_id in cond.get("seen_all", []):
		if int(seen.get(str(prior_id), 0)) <= 0:
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
		var amount := int(effects[key])
		if stat_id == "health" and absi(amount) <= 5:
			amount *= 8
		var after := clampi(before + amount, 0, stat_max(stat_id))
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
					var damount := int(damage[dkey])
					if did == "health" and absi(damount) <= 5:
						damount *= 8
					var dafter := clampi(dbefore + damount, 0, stat_max(did))
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
	filled = filled.replace("{chapter}", str(chapter))
	for id in STAT_ORDER:
		filled = filled.replace("{%s}" % id, str(int(stats.get(id, 0))))
	return filled


func _chapter_count() -> int:
	var list: Array = meta.get("chapters", [])
	return maxi(1, list.size())


func _chapter_info(number: int) -> Dictionary:
	var list: Array = meta.get("chapters", [])
	for item in list:
		if typeof(item) == TYPE_DICTIONARY and int(item.get("id", 0)) == number:
			return item
	var index := number - 1
	if index >= 0 and index < list.size() and typeof(list[index]) == TYPE_DICTIONARY:
		return list[index]
	return {}


func _chapter_of(ev: Dictionary) -> int:
	if ev.has("chapter"):
		return int(ev.get("chapter", 1))
	var cond: Dictionary = ev.get("when", {})
	if cond.has("chapter"):
		return int(cond.get("chapter", 1))
	return 1


func _highlights_seen() -> int:
	var count := 0
	for ev in events:
		if typeof(ev) != TYPE_DICTIONARY or not bool(ev.get("highlight", false)):
			continue
		if _chapter_of(ev) != chapter:
			continue
		if int(seen.get(str(ev.get("id", "")), 0)) > 0:
			count += 1
	return count


func _weight_of(ev: Dictionary) -> int:
	var weight := maxi(0, int(ev.get("weight", 1)))
	if weight <= 0 or not bool(ev.get("highlight", false)):
		return weight
	var count := _highlights_seen()
	if count >= 3:
		return 0
	# Подряд две изюминки не ставим: буст включается только после паузы.
	if last_highlight:
		return weight
	if count == 0 and day >= 5:
		return weight * 6
	if count == 1 and day >= 12:
		return weight * 6
	if count == 2 and day >= 18:
		return weight * 3
	return weight


func _finale_event() -> Dictionary:
	var finale_id := str(_chapter_info(chapter).get("finale", ""))
	if finale_id == "" or not by_id.has(finale_id):
		return {}
	var ev: Dictionary = by_id[finale_id]
	if _eligible(ev):
		return ev
	return {}


func _opening_or_pick(number: int) -> Dictionary:
	var opening := str(_chapter_info(number).get("opening", ""))
	if opening == "" and number == 1:
		opening = str(meta.get("opening_event", ""))
	if opening != "" and by_id.has(opening) and _eligible(by_id[opening]):
		return by_id[opening]
	return _pick("")


func _mark_chapter_break() -> void:
	chapter_break = true
	var info := _chapter_info(chapter)
	chapter_report = {
		"number": chapter,
		"name": str(info.get("name", chapter_title(chapter))),
		"line": str(info.get("clear_line", "Глава пройдена.")),
		"next": str(info.get("next_label", "Дальше")),
	}


func advance_chapter() -> void:
	if not chapter_break or chapter >= _chapter_count():
		chapter_break = false
		return
	chapter += 1
	day = 1
	chapter_break = false
	last_highlight = false
	pending = _opening_or_pick(chapter)
	save_checkpoint()


func peek_checkpoint() -> Dictionary:
	if not FileAccess.file_exists(CHECKPOINT_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CHECKPOINT_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


func save_checkpoint() -> void:
	var text := JSON.stringify(checkpoint_payload())
	if text.is_empty():
		return
	_write_text(CHECKPOINT_PATH, text)


func checkpoint_payload() -> Dictionary:
	return {
		"chapter": chapter,
		"day": day,
		"seed": seed_value,
		"rng_state": rng.state,
		"stats": stats.duplicate(),
		"flags": flags.duplicate(),
		"flag_order": flag_order.duplicate(),
		"seen": seen.duplicate(),
		"pending": str(pending.get("id", "")),
		"last_highlight": last_highlight,
		"weapon": weapon,
		"artifacts": artifacts.duplicate(),
		"bonus_max_hp": bonus_max_hp,
	}


func load_checkpoint() -> bool:
	var parsed := peek_checkpoint()
	if parsed.is_empty():
		return false
	load_data()
	seed_value = int(parsed.get("seed", 0))
	rng.seed = seed_value
	rng.state = int(parsed.get("rng_state", rng.state))
	chapter = maxi(1, int(parsed.get("chapter", 1)))
	day = maxi(1, int(parsed.get("day", 1)))
	days_to_win = int(meta.get("days_to_win", 90))
	chapter_days = int(meta.get("days_per_chapter", 30))
	chapter_break = false
	chapter_report = {}
	last_highlight = bool(parsed.get("last_highlight", false))
	run_over = false
	won = false
	ending_title = ""
	ending_line = ""
	last_reveal = {}
	stats.clear()
	var saved_stats: Dictionary = parsed.get("stats", {})
	var spec: Dictionary = meta.get("stats", {})
	for id in STAT_ORDER:
		stats[id] = int(saved_stats.get(id, spec.get(id, {}).get("start", 0)))
	flags.clear()
	flag_order.clear()
	var saved_flags: Dictionary = parsed.get("flags", {})
	for flag in parsed.get("flag_order", []):
		if bool(saved_flags.get(str(flag), false)):
			_set_flag(str(flag))
	for flag in saved_flags.keys():
		if bool(saved_flags[flag]):
			_set_flag(str(flag))
	seen.clear()
	var saved_seen: Dictionary = parsed.get("seen", {})
	for key in saved_seen.keys():
		seen[str(key)] = int(saved_seen[key])
	_load_meta()
	weapon = str(parsed.get("weapon", best_weapon))
	artifacts.clear()
	for item in parsed.get("artifacts", []):
		artifacts.append(str(item))
	_recompute_bonus()
	var pending_id := str(parsed.get("pending", ""))
	if pending_id != "" and by_id.has(pending_id):
		pending = by_id[pending_id]
	else:
		pending = _pick("")
	return true


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


func battle_blurb() -> String:
	return setup_text()


func battle_reward_text() -> String:
	var spec: Dictionary = _battle_pack.get("spec", {})
	var reward: Dictionary = spec.get("reward", {})
	var bits: Array[String] = []
	for key in reward.keys():
		bits.append("+%d %s" % [int(reward[key]), stat_label(str(key))])
	var found := str(spec.get("weapon", ""))
	if found != "":
		bits.append("оружие")
	if bits.is_empty():
		return "Победа: вы ещё дышите."
	return "Победа: " + ", ".join(bits)


func attack_tile() -> String:
	return weapon if weapon != "" else "baguette"


func grant_weapon(found: String) -> void:
	if WEAPON_ORDER.find(found) > WEAPON_ORDER.find(weapon):
		weapon = found
	if WEAPON_ORDER.find(found) > WEAPON_ORDER.find(best_weapon):
		best_weapon = found
		_save_meta()


func _maybe_artifact() -> void:
	var pool: Array[String] = ["backpack_patch", "sticking_plaster", "raisa_pepper", "zhek_notebook", "coffee_3in1", "electrical_tape", "postman_whistle", "training_grenade", "plastic_bag", "radio_antenna"]
	var open: Array[String] = []
	for item in pool:
		if not artifacts.has(item):
			open.append(item)
	if open.is_empty() or rng.randi_range(0, 2) > 0:
		return
	var pick: String = open[rng.randi_range(0, open.size() - 1)]
	artifacts.append(pick)
	if pick == "backpack_patch":
		bonus_max_hp += 8


func _recompute_bonus() -> void:
	bonus_max_hp = 5 if flat_medal else 0
	if artifacts.has("backpack_patch"):
		bonus_max_hp += 8


func _load_meta() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(META_PATH) != OK:
		best_weapon = "baguette"
		flat_medal = false
		return
	best_weapon = str(cfg.get_value("meta", "best_weapon", "baguette"))
	if WEAPON_ORDER.find(best_weapon) < 0:
		best_weapon = "baguette"
	flat_medal = bool(cfg.get_value("meta", "flat_medal", false))


func _save_meta() -> void:
	var cfg := ConfigFile.new()
	cfg.load(META_PATH)
	cfg.set_value("meta", "best_weapon", best_weapon)
	cfg.set_value("meta", "flat_medal", flat_medal)
	cfg.save(META_PATH)


func _write_text(path: String, text: String) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(text)
	file.close()
	return OK

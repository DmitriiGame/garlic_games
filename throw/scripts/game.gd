extends Node
## Правила броска, загона и кошелька. Экран и симуляция зовут одни и те же функции.

const SAVE_PATH := "user://save.json"
const KNOWN_UPGRADES: Array[String] = ["throw_power", "pen_slots", "pen_income", "lure"]

var currency := 0.0
var best_distance := 0.0
var throw_count := 0
var catch_count := 0
var total_earned := 0.0
var tutorial_throws := 0
var equipped := ""
var owned: Dictionary = {}
var levels: Dictionary = {}
var caught: Dictionary = {}
var unlocked: Dictionary = {}
var last_unix := 0
var offline_report: Dictionary = {}
var rng := RandomNumberGenerator.new()
var allow_save := true
var clock_override := -1


func _ready() -> void:
	load_progress()


func now_unix() -> int:
	if clock_override >= 0:
		return clock_override
	return int(Time.get_unix_time_from_system())


func load_progress() -> void:
	Content.load_all()
	_blank_state()
	if not FileAccess.file_exists(SAVE_PATH):
		last_unix = now_unix()
		_zero_offline()
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		last_unix = now_unix()
		_zero_offline()
		return
	_apply_save(parsed)
	if int(parsed.get("last_unix", 0)) <= 0:
		last_unix = now_unix()
		_zero_offline()
		return
	apply_offline()


func wipe_progress() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	_blank_state()
	last_unix = now_unix()
	rng.randomize()
	_zero_offline()
	save_progress()


func reset_run(seed_value: int) -> void:
	Content.load_all()
	_blank_state()
	rng.seed = seed_value
	_zero_offline()


func save_progress() -> bool:
	if not allow_save:
		return false
	last_unix = now_unix()
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Бросай и лови: сохранение не записалось (%s)" % error_string(FileAccess.get_open_error()))
		return false
	file.store_string(JSON.stringify(DataFiles.sanitize(save_dict()), "\t") + "\n")
	return true


func save_dict() -> Dictionary:
	return {
		"version": 1,
		"currency": currency,
		"best_distance": best_distance,
		"throw_count": throw_count,
		"catch_count": catch_count,
		"total_earned": total_earned,
		"tutorial_throws": tutorial_throws,
		"equipped": equipped,
		"owned": owned.duplicate(),
		"levels": levels.duplicate(),
		"caught": caught.duplicate(),
		"unlocked": unlocked.duplicate(),
		"last_unix": last_unix,
	}


func accrue(seconds: float) -> float:
	if seconds <= 0.0:
		return 0.0
	var gained := income_per_sec() * seconds
	currency += gained
	total_earned += gained
	return gained


func apply_offline() -> Dictionary:
	var now := now_unix()
	var elapsed := maxi(0, now - last_unix)
	var cap := int(Content.balance.get("offline_cap_sec", 28800))
	var paid := mini(elapsed, cap)
	var gained := income_per_sec() * float(paid)
	currency += gained
	total_earned += gained
	last_unix = now
	offline_report = {
		"gained": gained,
		"elapsed": elapsed,
		"paid": paid,
		"capped": elapsed > cap and gained > 0.0,
	}
	return offline_report


func repair_state() -> void:
	if not Content.item_by_id.has(equipped):
		equipped = _starter_id()
	if equipped != "":
		owned[equipped] = true
	reapply_unlocks()


func reapply_unlocks() -> void:
	for biome in Content.biomes:
		var id := str(biome.get("id", ""))
		if id == "":
			continue
		if best_distance + 0.0001 >= float(biome.get("unlock_distance", 0)):
			unlocked[id] = true
	if unlocked.is_empty() and not Content.biomes.is_empty():
		unlocked[str(Content.biomes[0].get("id", ""))] = true


func distance_for_power(power: float) -> float:
	var base := float(Content.balance.get("base_distance", 0))
	var span := float(Content.balance.get("power_distance", 0))
	return base + clampf(power, 0.0, 1.0) * span * throw_multiplier()


func power_for_distance(want: float) -> float:
	var bonus := float(Content.balance.get("power_distance", 0)) * throw_multiplier()
	if bonus <= 0.001:
		return 1.0
	var base := float(Content.balance.get("base_distance", 0))
	return clampf((want - base) / bonus, 0.0, 1.0)


func max_distance() -> float:
	return distance_for_power(1.0)


func distance_if(extra_levels: int, item_id: String) -> float:
	var base := float(Content.balance.get("base_distance", 0))
	var span := float(Content.balance.get("power_distance", 0))
	return base + span * _multiplier_for(extra_levels, item_id)


func theoretical_max_distance() -> float:
	var best_mult := 1.0
	for item in Content.items:
		best_mult = maxf(best_mult, float(item.get("throw_mult", 1)))
	var cap_level := int(Content.upgrade_by_id.get("throw_power", {}).get("max_level", 0))
	var step := float(Content.balance.get("throw_step", 0))
	var mult := best_mult * (1.0 + float(cap_level) * step)
	return float(Content.balance.get("base_distance", 0)) + float(Content.balance.get("power_distance", 0)) * mult


func throw_multiplier() -> float:
	return _multiplier_for(0, equipped)


func preview_view() -> float:
	var reach := max_distance()
	var nxt := next_biome()
	var goal := float(nxt.get("unlock_distance", 0)) if not nxt.is_empty() else 0.0
	return maxf(reach, goal) * 1.12 + 8.0


func biome_at(distance: float) -> Dictionary:
	var best: Dictionary = {}
	for biome in Content.biomes:
		if float(biome.get("unlock_distance", 0)) <= distance + 0.0001:
			best = biome
	if best.is_empty() and not Content.biomes.is_empty():
		best = Content.biomes[0]
	return best


func next_biome() -> Dictionary:
	for biome in Content.biomes:
		if not unlocked.has(str(biome.get("id", ""))):
			return biome
	return {}


func band_end(index: int) -> float:
	if index + 1 < Content.biomes.size():
		return float(Content.biomes[index + 1].get("unlock_distance", 0))
	return max_distance() + 80.0


func spawn_count() -> int:
	var item: Dictionary = Content.item_by_id.get(equipped, {})
	var count := int(Content.balance.get("base_spawns", 3))
	count += int(item.get("lure", 0))
	count += int(levels.get("lure", 0)) * int(Content.balance.get("lure_per_level", 1))
	return clampi(count, 1, int(Content.balance.get("max_spawns", 6)))


func pen_capacity() -> int:
	return maxi(1, int(Content.balance.get("start_pen", 3)) + int(levels.get("pen_slots", 0)))


func income_multiplier() -> float:
	return 1.0 + float(int(levels.get("pen_income", 0))) * float(Content.balance.get("income_step", 0))


func creature_rate(id: String) -> float:
	var count := int(caught.get(id, 0))
	if count <= 0:
		return 0.0
	var creature: Dictionary = Content.creature_by_id.get(id, {})
	if creature.is_empty():
		return 0.0
	var row := Content.rarity(str(creature.get("rarity", "")))
	var stacks := mini(count, int(Content.balance.get("duplicate_cap", 1)))
	var stack_mult := 1.0 + float(Content.balance.get("duplicate_bonus", 0)) * float(stacks - 1)
	var scale := float(creature.get("income_scale", 1))
	return float(row.get("income", 0)) * scale * stack_mult * income_multiplier()


func pen_members() -> Array:
	var ranked: Array = []
	for creature in Content.creatures:
		var id := str(creature.get("id", ""))
		var rate := creature_rate(id)
		if rate <= 0.0:
			continue
		ranked.append({"id": id, "rate": rate, "count": int(caught.get(id, 0))})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.rate) > float(b.rate)
	)
	return ranked.slice(0, pen_capacity())


func income_per_sec() -> float:
	var total := 0.0
	for member in pen_members():
		total += float(member.rate)
	return total


func window_for(id: String) -> float:
	var creature: Dictionary = Content.creature_by_id.get(id, {})
	var row := Content.rarity(str(creature.get("rarity", "")))
	return maxf(0.45, float(row.get("window", 1.5)))


func catch_bonus(id: String) -> int:
	var creature: Dictionary = Content.creature_by_id.get(id, {})
	var row := Content.rarity(str(creature.get("rarity", "")))
	return maxi(0, int(row.get("catch_bonus", 0)))


func commit_throw(power: float) -> Dictionary:
	power = clampf(power, 0.0, 1.0)
	var distance := distance_for_power(power)
	throw_count += 1
	tutorial_throws += 1
	var newly: Array = register_distance(distance)
	var biome := biome_at(distance)
	var spawns := roll_spawns(str(biome.get("id", "")))
	return {
		"power": power,
		"distance": distance,
		"biome": biome,
		"spawns": spawns,
		"unlocked": newly,
	}


func register_distance(distance: float) -> Array:
	if distance > best_distance:
		best_distance = distance
	var newly: Array = []
	for biome in Content.biomes:
		var id := str(biome.get("id", ""))
		if id == "" or unlocked.has(id):
			continue
		if best_distance + 0.0001 >= float(biome.get("unlock_distance", 0)):
			unlocked[id] = true
			newly.append(id)
	return newly


func roll_spawns(biome_id: String) -> Array:
	var pool: Array = []
	var total := 0
	for creature in Content.creatures:
		if str(creature.get("biome", "")) != biome_id:
			continue
		var weight := int(creature.get("weight", 0))
		if weight <= 0:
			continue
		pool.append(creature)
		total += weight
	var out: Array = []
	if total <= 0 or pool.is_empty():
		return out
	for _n in spawn_count():
		var roll := rng.randi_range(1, total)
		var acc := 0
		var picked := str(pool[0].get("id", ""))
		for creature in pool:
			acc += int(creature.get("weight", 0))
			if roll <= acc:
				picked = str(creature.get("id", ""))
				break
		out.append(picked)
	return out


func register_catch(id: String) -> Dictionary:
	var creature: Dictionary = Content.creature_by_id.get(id, {})
	var was := int(caught.get(id, 0))
	caught[id] = was + 1
	catch_count += 1
	var bonus := catch_bonus(id)
	currency += float(bonus)
	total_earned += float(bonus)
	return {
		"id": id,
		"name": str(creature.get("name", id)),
		"first": was == 0,
		"bonus": bonus,
		"count": was + 1,
		"line": str(creature.get("line", "")),
	}


func upgrade_cost(id: String) -> int:
	var upgrade: Dictionary = Content.upgrade_by_id.get(id, {})
	if upgrade.is_empty():
		return -1
	var level := int(levels.get(id, 0))
	if level >= int(upgrade.get("max_level", 0)):
		return -1
	var cost := float(upgrade.get("base_cost", 1)) * pow(float(upgrade.get("growth", 1.5)), float(level))
	return maxi(0, int(round(cost)))


func upgrade_level(id: String) -> int:
	return int(levels.get(id, 0))


func try_buy(token: String) -> bool:
	var parts := token.split(":", false, 1)
	if parts.size() != 2:
		return false
	var kind := str(parts[0])
	var id := str(parts[1])
	if kind == "upgrade":
		var cost := upgrade_cost(id)
		if cost < 0 or currency + 0.001 < float(cost):
			return false
		currency -= float(cost)
		levels[id] = int(levels.get(id, 0)) + 1
		return true
	if kind == "item":
		var item: Dictionary = Content.item_by_id.get(id, {})
		if item.is_empty() or owned.has(id):
			return false
		var price := int(item.get("price", 0))
		if currency + 0.001 < float(price):
			return false
		currency -= float(price)
		owned[id] = true
		equipped = id
		return true
	if kind == "equip":
		if not owned.has(id) or not Content.item_by_id.has(id):
			return false
		equipped = id
		return true
	return false


func biome_missing(biome_id: String) -> int:
	var missing := 0
	for creature in Content.creatures:
		if str(creature.get("biome", "")) != biome_id:
			continue
		if int(caught.get(str(creature.get("id", "")), 0)) <= 0:
			missing += 1
	return missing


func collection_complete() -> bool:
	if Content.creatures.is_empty():
		return false
	for creature in Content.creatures:
		if int(caught.get(str(creature.get("id", "")), 0)) <= 0:
			return false
	return true


func unique_caught() -> int:
	var count := 0
	for creature in Content.creatures:
		if int(caught.get(str(creature.get("id", "")), 0)) > 0:
			count += 1
	return count


func missing_ids() -> Array[String]:
	var missing: Array[String] = []
	for creature in Content.creatures:
		var id := str(creature.get("id", ""))
		if int(caught.get(id, 0)) <= 0:
			missing.append(id)
	return missing


func goal_text() -> String:
	var nxt := next_biome()
	if nxt.is_empty():
		return "все края открыты"
	var left := maxf(0.0, float(nxt.get("unlock_distance", 0)) - best_distance)
	return "до «%s» ещё %d м" % [nxt.get("name", ""), int(ceil(left))]


func economy_line() -> String:
	var item: Dictionary = Content.item_by_id.get(equipped, {})
	return "замах %d, %s, %s, %s, бестиарий %d/%d, бросков %d" % [
		upgrade_level("throw_power"),
		item.get("name", equipped),
		format_rate(income_per_sec()),
		format_money(currency),
		unique_caught(),
		Content.creatures.size(),
		throw_count,
	]


func format_money(value: float) -> String:
	if value < 100.0:
		return "%s %s" % [_comma(value, 1), money_word(int(round(value)))]
	return "%s %s" % [_group(int(floor(value))), money_word(int(floor(value)))]


func format_rate(value: float) -> String:
	return "%s / сек" % _comma(value, 2)


func format_duration(seconds: float) -> String:
	var whole := maxi(0, int(round(seconds)))
	var hours := int(whole / 3600)
	var minutes := int((whole % 3600) / 60)
	var secs := whole % 60
	if hours > 0 and minutes > 0:
		return "%d ч %d мин" % [hours, minutes]
	if hours > 0:
		return "%d ч" % hours
	if minutes > 0:
		return "%d мин" % minutes
	return "%d с" % secs


func money_word(number: int) -> String:
	var one := str(Content.balance.get("currency_one", "грош"))
	var few := str(Content.balance.get("currency_few", "гроша"))
	var many := str(Content.balance.get("currency_many", "грошей"))
	var tail := absi(number) % 100
	var digit := tail % 10
	if tail > 10 and tail < 20:
		return many
	if digit == 1:
		return one
	if digit >= 2 and digit <= 4:
		return few
	return many


func offline_line() -> String:
	var gained := float(offline_report.get("gained", 0))
	var elapsed := int(offline_report.get("elapsed", 0))
	var text := "Пока тебя не было (%s), загон принёс %s." % [format_duration(elapsed), format_money(gained)]
	if bool(offline_report.get("capped", false)):
		var cap := int(Content.balance.get("offline_cap_sec", 28800))
		text += " Дольше %s они без тебя ленятся." % format_duration(cap)
	return text


func _blank_state() -> void:
	currency = float(Content.balance.get("start_currency", 0))
	best_distance = 0.0
	throw_count = 0
	catch_count = 0
	total_earned = currency
	tutorial_throws = 0
	equipped = _starter_id()
	owned = {}
	if equipped != "":
		owned[equipped] = true
	levels = {}
	caught = {}
	unlocked = {}
	last_unix = 0
	for biome in Content.biomes:
		if float(biome.get("unlock_distance", 0)) <= 0.0001:
			unlocked[str(biome.get("id", ""))] = true
	if unlocked.is_empty() and not Content.biomes.is_empty():
		unlocked[str(Content.biomes[0].get("id", ""))] = true
	rng.randomize()


func _apply_save(data: Dictionary) -> void:
	currency = float(data.get("currency", 0))
	best_distance = float(data.get("best_distance", 0))
	throw_count = int(data.get("throw_count", 0))
	catch_count = int(data.get("catch_count", 0))
	total_earned = float(data.get("total_earned", currency))
	tutorial_throws = int(data.get("tutorial_throws", throw_count))
	equipped = str(data.get("equipped", _starter_id()))
	owned = _flag_dict(data.get("owned", {}))
	levels = {}
	var stored_levels = data.get("levels", {})
	if typeof(stored_levels) == TYPE_DICTIONARY:
		for key in stored_levels.keys():
			levels[str(key)] = maxi(0, int(stored_levels[key]))
	caught = {}
	var stored_caught = data.get("caught", {})
	if typeof(stored_caught) == TYPE_DICTIONARY:
		for key in stored_caught.keys():
			var id := str(key)
			if Content.creature_by_id.has(id):
				caught[id] = maxi(0, int(stored_caught[key]))
	unlocked = _flag_dict(data.get("unlocked", {}))
	last_unix = int(data.get("last_unix", 0))
	repair_state()


func _flag_dict(value: Variant) -> Dictionary:
	var out := {}
	if typeof(value) == TYPE_ARRAY:
		for id in value:
			out[str(id)] = true
	elif typeof(value) == TYPE_DICTIONARY:
		for id in value.keys():
			if bool(value[id]):
				out[str(id)] = true
	return out


func _zero_offline() -> void:
	offline_report = {"gained": 0.0, "elapsed": 0, "paid": 0, "capped": false}


func _starter_id() -> String:
	if Content.items.is_empty():
		return ""
	return str(Content.items[0].get("id", ""))


func _item_mult(item_id: String) -> float:
	var item: Dictionary = Content.item_by_id.get(item_id, {})
	if item.is_empty() and not Content.items.is_empty():
		item = Content.items[0]
	return maxf(0.01, float(item.get("throw_mult", 1)))


func _multiplier_for(extra_levels: int, item_id: String) -> float:
	var step := float(Content.balance.get("throw_step", 0))
	var level := int(levels.get("throw_power", 0)) + extra_levels
	return _item_mult(item_id) * (1.0 + float(level) * step)


func _comma(value: float, digits: int) -> String:
	return ("%.*f" % [digits, value]).replace(".", ",")


func _group(number: int) -> String:
	var sign := ""
	if number < 0:
		sign = "-"
		number = -number
	var text := str(number)
	var grouped := ""
	while text.length() > 3:
		grouped = " " + text.substr(text.length() - 3, 3) + grouped
		text = text.substr(0, text.length() - 3)
	return sign + text + grouped

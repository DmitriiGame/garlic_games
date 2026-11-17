extends SceneTree
## Прогон без окна: правила, экран одного броска и время до краёв и полного бестиария.

const ACTIVE_LIMIT = 6.0 * 3600.0
const LAZY_LIMIT = 8.0 * 3600.0


func _initialize() -> void:
	if root.get_node_or_null("Game") == null or root.get_node_or_null("Content") == null:
		push_error("Нет автозагрузки Game или Content")
		quit(1)
		return
	call_deferred("_boot")


func _boot() -> void:
	_game().allow_save = false
	var errors: Array[String] = []
	if not _content().problems.is_empty():
		for problem in _content().problems:
			errors.append(str(problem))
		_finish(errors)
		return
	_check_rules(errors)
	_check_screen(errors)
	if not errors.is_empty():
		_finish(errors)
		return
	var rates: Dictionary = _content().balance.get("sim", {}).get("catch_rate", {})
	var cycle = float(_content().balance.get("sim", {}).get("throw_cycle_sec", 8))
	print("=== Бросай и лови: баланс ===")
	print("Активный игрок целится в ближайший неполный край, сначала покупает дальность, потом приманку и загон.")
	print("Цикл броска %s с. Шансы поимки в расчёте, не в игре: %s." % [_comma(cycle, 0), _rate_line(rates)])
	var detailed: Dictionary = _play(1000, cycle, rates, ACTIVE_LIMIT, true)
	_print_run("Сид 1000", detailed)
	var active_runs: Array = [detailed]
	for extra in 6:
		active_runs.append(_play(1017 + extra * 19, cycle, rates, ACTIVE_LIMIT, false))
	_print_median("Медиана 7 активных сидов", active_runs)
	var lazy_rates = {}
	for key in rates.keys():
		lazy_rates[key] = float(rates[key]) * 0.75
	var lazy_runs: Array = []
	for extra in 5:
		lazy_runs.append(_play(2000 + extra * 13, cycle + 4.0, lazy_rates, LAZY_LIMIT, false))
	_print_median("Медиана 5 ленивых сидов (цикл %.0f с, шанс ниже)" % (cycle + 4.0), lazy_runs)
	for run in active_runs:
		if float(run.completed) < 0.0:
			errors.append("активный игрок не собрал бестиарий за %s" % _game().format_duration(ACTIVE_LIMIT))
			break
	for biome in _content().biomes:
		var id = str(biome.get("id", ""))
		var times: Array = []
		for run in active_runs:
			if not run.unlock_at.has(id):
				errors.append("край %s не открылся" % biome.get("name", id))
				break
			times.append(float(run.unlock_at[id]))
		if times.size() == active_runs.size():
			print("  медиана «%s»: %s" % [biome.get("name", id), _clock(_median(times))])
	if not errors.is_empty():
		var sample: Dictionary = active_runs[0]
		print("Не пойманы: ", ", ".join(sample.missing))
		print(_game().economy_line())
	_finish(errors)


func _check_rules(errors: Array[String]) -> void:
	for id in ["throw_power", "pen_slots", "pen_income", "lure"]:
		if not _content().upgrade_by_id.has(id):
			errors.append("нет улучшения %s" % id)
	_game().reset_run(8)
	var base = float(_content().balance.get("base_distance", 0))
	if absf(_game().distance_for_power(0.0) - base) > 0.001:
		errors.append("нулевая сила не равна минимальной дальности")
	if _game().distance_for_power(1.0) <= _game().distance_for_power(0.0):
		errors.append("полная сила не дальше нулевой")
	if str(_game().biome_at(0.0).get("id", "")) != "yard":
		errors.append("нулевая дальность не во дворе")
	var garden_at = float(_content().biome_by_id.garden.unlock_distance)
	if str(_game().biome_at(garden_at - 0.2).get("id", "")) != "yard":
		errors.append("перед огородом уже огород")
	if str(_game().biome_at(garden_at).get("id", "")) != "garden":
		errors.append("порог огорода не открывает огород")
	var last = float(_content().biomes[_content().biomes.size() - 1].get("unlock_distance", 0))
	if _game().theoretical_max_distance() < last + 5.0:
		errors.append("полная прокачка не достаёт до последнего края")
	if _game().max_distance() >= last:
		errors.append("стартовый бросок уже достаёт до последнего края")
	_game().currency = 0
	if _game().try_buy("upgrade:throw_power") or _game().upgrade_level("throw_power") != 0:
		errors.append("замах купился без грошей")
	_game().currency = 1000000
	var before: float = _game().max_distance()
	if not _game().try_buy("upgrade:throw_power") or _game().max_distance() <= before:
		errors.append("замах не увеличил дальность")
	var common_id = _first_rarity("common")
	_game().reset_run(6)
	_game().register_catch(common_id)
	var once: float = _game().creature_rate(common_id)
	_game().register_catch(common_id)
	if _game().creature_rate(common_id) <= once:
		errors.append("повторная поимка не увеличила доход")
	_game().reset_run(3)
	var seen = {}
	var caught_kinds = 0
	for creature in _content().creatures:
		var id = str(creature.get("id", ""))
		if seen.has(str(creature.get("rarity", ""))):
			continue
		seen[str(creature.get("rarity", ""))] = true
		_game().register_catch(id)
		caught_kinds += 1
		if caught_kinds >= 5:
			break
	if _game().pen_members().size() != mini(caught_kinds, _game().pen_capacity()):
		errors.append("в загоне %d вместо %d" % [_game().pen_members().size(), mini(caught_kinds, _game().pen_capacity())])
	_game().reset_run(4)
	_game().clock_override = 10000
	_game().last_unix = 10000
	_game().register_catch(common_id)
	var rate: float = _game().income_per_sec()
	if rate <= 0.0:
		errors.append("пойманный не приносит доход")
	var cap = int(_content().balance.get("offline_cap_sec", 0))
	if cap < 60 or cap > 14 * 24 * 3600:
		errors.append("потолок оффлайна не похож на здравый: %s с" % cap)
	_game().clock_override = 10000 + cap + 5000
	var report: Dictionary = _game().apply_offline()
	if int(report.paid) != cap:
		errors.append("оффлайн оплатил %s вместо %s" % [report.paid, cap])
	if absf(float(report.gained) - rate * float(cap)) > 0.05:
		errors.append("оффлайн сумма %s, ждали %s" % [report.gained, rate * cap])
	if not bool(report.capped):
		errors.append("оффлайн не упёрся в потолок")
	var line = str(_game().offline_line())
	if not line.contains("загон"):
		errors.append("текст оффлайна пустой")
	_game().last_unix = int(_game().clock_override) + 80
	var backwards: Dictionary = _game().apply_offline()
	if int(backwards.elapsed) != 0 or float(backwards.gained) > 0.0:
		errors.append("время назад начислило доход")
	_game().clock_override = -1


func _check_screen(errors: Array[String]) -> void:
	_game().allow_save = false
	_game().reset_run(42)
	var packed = load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		errors.append("сцена не грузится")
		return
	var main = packed.instantiate()
	root.add_child(main)
	var thrown: Dictionary = main.debug_force_round(0.95)
	if thrown.get("spawns", []).size() < 1:
		errors.append("бросок никого не позвал")
	var caught: int = main.debug_catch_all()
	if caught < 1 or _game().catch_count < 1:
		errors.append("экран не отдал поимку")
	if str(main.debug_phase()) != "catch":
		errors.append("после броска игра не в ловле")
	main._show_tab(1)
	main._show_tab(2)
	main._show_tab(3)
	_game().currency = 100000
	if not main.debug_press_buy("upgrade", "throw_power"):
		errors.append("лавка не продала замах")
	var editor = CatalogEditor.new()
	root.add_child(editor)
	editor.set_bundle(_content().bundle())
	for section in 6:
		editor.debug_open_section(section)
	editor.debug_open_section(2)
	var before = float(editor.edited_bundle().biomes.biomes[0].unlock_distance)
	var nudged: Dictionary = editor.debug_nudge_first_spin()
	var after = float(editor.edited_bundle().biomes.biomes[0].unlock_distance)
	if str(nudged.get("key", "")) != "unlock_distance":
		errors.append("редактор крутанул не дальность, а %s" % nudged.get("key", ""))
	if after <= before:
		errors.append("редактор не записал спин")
	main.queue_free()
	editor.queue_free()


func _play(seed_value: int, cycle: float, rates: Dictionary, limit: float, verbose: bool) -> Dictionary:
	_game().reset_run(seed_value)
	var unlock_at = {}
	for biome in _content().biomes:
		var id = str(biome.get("id", ""))
		if _game().unlocked.has(id):
			unlock_at[id] = 0.0
	if verbose:
		print("Сид %d" % seed_value)
		print("  0:00:00  Двор уже открыт · %s" % _game().economy_line())
	var caught_at = {}
	var t = 0.0
	var completed = -1.0
	while t < limit:
		if _game().collection_complete():
			completed = t
			break
		var thrown: Dictionary = _game().commit_throw(_aim_power())
		for id in thrown.spawns:
			_try_catch(str(id), rates, caught_at, t)
		for id in thrown.unlocked:
			if not unlock_at.has(str(id)):
				unlock_at[str(id)] = t
				if verbose:
					var biome: Dictionary = _content().biome_by_id.get(str(id), {})
					print("  %s  край «%s» · %s" % [_clock(t), biome.get("name", id), _game().economy_line()])
		_game().accrue(cycle)
		_spend(8)
		t += cycle
	if completed < 0.0 and _game().collection_complete():
		completed = t
	if verbose and completed >= 0.0:
		print("  %s  Бестиарий полный · %s" % [_clock(completed), _game().economy_line()])
		var cap = int(_content().balance.get("offline_cap_sec", 0))
		var payout = _game().income_per_sec() * float(cap)
		print("Если закрыть игру на %s при доходе конца этого забега (%s), придёт %s." % [
			_game().format_duration(cap), _game().format_rate(_game().income_per_sec()), _game().format_money(payout),
		])
		print("Дольше потолка загон без хозяина не копит.")
	return {
		"completed": completed,
		"unlock_at": unlock_at,
		"missing": _game().missing_ids(),
		"throws": _game().throw_count,
		"catches": _game().catch_count,
		"earned": _game().total_earned,
	}


func _aim_power() -> float:
	var index = _target_index()
	var biome: Dictionary = _content().biomes[index]
	var unlock = float(biome.get("unlock_distance", 0))
	if _game().max_distance() + 0.01 < unlock:
		return 1.0
	var lo = unlock + 0.8
	var hi = _game().band_end(index) - 0.8
	if hi < lo:
		hi = lo
	var want = (lo + hi) * 0.5
	if index == _content().biomes.size() - 1:
		want = unlock + 8.0
	return _game().power_for_distance(minf(want, _game().max_distance()))


func _target_index() -> int:
	var fallback = _content().biomes.size() - 1
	var have_fallback = false
	for index in _content().biomes.size():
		var biome: Dictionary = _content().biomes[index]
		if _game().biome_missing(str(biome.get("id", ""))) <= 0:
			continue
		if not have_fallback:
			fallback = index
			have_fallback = true
		if _game().max_distance() + 0.01 >= float(biome.get("unlock_distance", 0)):
			return index
	return fallback


func _try_catch(id: String, rates: Dictionary, caught_at: Dictionary, t: float) -> void:
	var creature: Dictionary = _content().creature_by_id.get(id, {})
	var rarity = str(creature.get("rarity", ""))
	var chance = float(rates.get(rarity, 0.5))
	if _game().rng.randf() >= chance:
		return
	var was_new = int(_game().caught.get(id, 0)) <= 0
	_game().register_catch(id)
	if was_new:
		caught_at[id] = t


func _spend(limit: int) -> void:
	for _step in limit:
		var token = _best_buy()
		if token == "":
			return
		var before: float = _game().currency
		var level_before = _game().upgrade_level("throw_power")
		var item_before = _game().equipped
		if not _game().try_buy(token):
			return
		if _game().currency >= before and _game().upgrade_level("throw_power") == level_before and _game().equipped == item_before and not token.begins_with("upgrade:lure") and not token.begins_with("upgrade:pen"):
			return


func _best_buy() -> String:
	var blocked = -1.0
	for biome in _content().biomes:
		if _game().biome_missing(str(biome.get("id", ""))) <= 0:
			continue
		if _game().max_distance() + 0.01 < float(biome.get("unlock_distance", 0)):
			blocked = float(biome.get("unlock_distance", 0))
			break
	if blocked >= 0.0:
		return _best_distance_buy(blocked)
	if _game().collection_complete():
		return ""
	if _game().spawn_count() < int(_content().balance.get("max_spawns", 6)):
		var lure_cost = _game().upgrade_cost("lure")
		if lure_cost >= 0 and _game().currency + 0.001 >= float(lure_cost):
			return "upgrade:lure"
	return _best_income_buy()


func _best_distance_buy(target: float) -> String:
	var options: Array = []
	var throw_cost = _game().upgrade_cost("throw_power")
	if throw_cost >= 0 and _game().currency + 0.001 >= float(throw_cost):
		options.append({
			"token": "upgrade:throw_power",
			"cost": throw_cost,
			"reach": _game().distance_if(1, _game().equipped),
			"gain": _game().distance_if(1, _game().equipped) - _game().max_distance(),
		})
	for item in _content().items:
		var id = str(item.get("id", ""))
		if _game().owned.has(id):
			continue
		var price = int(item.get("price", 0))
		if _game().currency + 0.001 < float(price):
			continue
		var reach: float = _game().distance_if(0, id)
		options.append({
			"token": "item:%s" % id,
			"cost": price,
			"reach": reach,
			"gain": reach - _game().max_distance(),
		})
	if options.is_empty():
		return ""
	var reaching: Array = []
	for option in options:
		if float(option.reach) + 0.01 >= target and float(option.gain) > 0.05:
			reaching.append(option)
	if not reaching.is_empty():
		reaching.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a.cost) < int(b.cost)
		)
		return str(reaching[0].token)
	options.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.gain) / maxf(1.0, float(a.cost)) > float(b.gain) / maxf(1.0, float(b.cost))
	)
	if float(options[0].gain) <= 0.05:
		return ""
	return str(options[0].token)


func _best_income_buy() -> String:
	var backup: Dictionary = _game().levels.duplicate()
	var best = ""
	var best_score = 0.0
	for id in ["pen_income", "pen_slots"]:
		var cost = _game().upgrade_cost(id)
		if cost < 0 or _game().currency + 0.001 < float(cost):
			continue
		var before: float = _game().income_per_sec()
		_game().levels[id] = int(_game().levels.get(id, 0)) + 1
		var after: float = _game().income_per_sec()
		_game().levels = backup.duplicate()
		var gain = after - before
		if gain <= 0.00001:
			continue
		if float(cost) / gain > 20.0 * 60.0:
			continue
		var score = gain / float(cost)
		if score > best_score:
			best_score = score
			best = "upgrade:%s" % id
	_game().levels = backup
	return best


func _print_run(title: String, run: Dictionary) -> void:
	if float(run.completed) < 0.0:
		print("%s не собрал бестиарий. Бросков %d, поимок %d, не хватает: %s" % [
			title, int(run.throws), int(run.catches), ", ".join(run.missing),
		])
		return
	print("%s: полный бестиарий %s, бросков %d, поимок %d, заработано %s" % [
		title, _clock(float(run.completed)), int(run.throws), int(run.catches), _game().format_money(float(run.earned)),
	])


func _print_median(title: String, runs: Array) -> void:
	var done: Array = []
	var failed = 0
	for run in runs:
		if float(run.completed) < 0.0:
			failed += 1
		else:
			done.append(float(run.completed))
	if done.is_empty():
		print("%s: никто не собрал бестиарий." % title)
		return
	var spread = ""
	if done.size() > 1:
		var copy: Array = done.duplicate()
		copy.sort()
		spread = " (от %s до %s)" % [_clock(float(copy[0])), _clock(float(copy[copy.size() - 1]))]
	var fail_note = ""
	if failed > 0:
		fail_note = ", не уложились: %d" % failed
	print("%s: полный бестиарий %s%s%s" % [title, _clock(_median(done)), spread, fail_note])


func _median(values: Array) -> float:
	var copy: Array = values.duplicate()
	copy.sort()
	var count = copy.size()
	if count == 0:
		return -1.0
	if count % 2 == 1:
		return float(copy[count / 2])
	return (float(copy[count / 2 - 1]) + float(copy[count / 2])) * 0.5


func _first_rarity(rarity: String) -> String:
	for creature in _content().creatures:
		if str(creature.get("rarity", "")) == rarity:
			return str(creature.get("id", ""))
	return str(_content().creatures[0].get("id", ""))


func _rate_line(rates: Dictionary) -> String:
	var parts: Array[String] = []
	for key in rates.keys():
		parts.append("%s %s" % [key, _comma(float(rates[key]), 2)])
	return ", ".join(parts)


func _clock(seconds: float) -> String:
	var whole = maxi(0, int(round(seconds)))
	var hours = int(whole / 3600)
	var minutes = int((whole % 3600) / 60)
	var secs = whole % 60
	return "%d:%02d:%02d" % [hours, minutes, secs]


func _comma(value: float, digits: int) -> String:
	return ("%.*f" % [digits, value]).replace(".", ",")


func _game():
	return root.get_node("Game")


func _content():
	return root.get_node("Content")


func _finish(errors: Array[String]) -> void:
	if errors.is_empty():
		print("SIM OK")
		quit(0)
		return
	for err in errors:
		push_error(err)
	print("SIM FAIL ", errors.size())
	quit(1)

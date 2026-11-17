extends SceneTree
## Прогон правил без окна: смерть, победа, цепочки флагов, отсутствие дыр в данных.

const STATS: Array[String] = ["food", "health", "sanity", "ammo"]


func _initialize() -> void:
	var game: Node = root.get_node_or_null("Game")
	if game == null:
		push_error("Нет автозагрузки Game")
		quit(1)
		return
	var errors: Array[String] = []
	game.load_data()
	_check_data(game, errors)
	_check_chains(game, errors)
	var careful_n := 120
	var careful := _play_many(game, "careful", careful_n)
	var reckless := _play_many(game, "reckless", 20)
	var random_runs := _play_many(game, "random", 24)
	print("careful ", careful)
	print("reckless ", reckless)
	print("random ", random_runs)
	_check_rates(careful, careful_n, errors)
	if int(reckless.get("deaths", 0)) < 1:
		errors.append("безрассудная стратегия ни разу не умерла")
	if int(random_runs.get("deaths", 0)) < 1:
		errors.append("случайная стратегия ни разу не умерла")
	if int(careful.get("wins", 0)) < 1:
		errors.append("осторожная стратегия ни разу не прошла все главы")
	_scripted_death(game, errors)
	if errors.is_empty():
		print("SIM OK")
		quit(0)
	else:
		for err in errors:
			push_error(err)
		print("SIM FAIL ", errors.size())
		quit(1)


func _check_data(game: Node, errors: Array[String]) -> void:
	if game.events.is_empty():
		errors.append("пустой список событий")
		return
	var scenes := {}
	for scene_name in game.KNOWN_SCENES:
		scenes[scene_name] = true
	var per_chapter := {}
	for ev in game.events:
		var id := str(ev.get("id", ""))
		if not scenes.has(str(ev.get("scene", ""))):
			errors.append("%s: неизвестная сцена %s" % [id, ev.get("scene", "")])
		var chapter := int(ev.get("chapter", ev.get("when", {}).get("chapter", 1)))
		per_chapter[chapter] = int(per_chapter.get(chapter, 0)) + 1
		if chapter < 1 or chapter > 3:
			errors.append("%s: глава вне 1–3" % id)
		if typeof(ev.get("a")) != TYPE_DICTIONARY or typeof(ev.get("b")) != TYPE_DICTIONARY:
			errors.append("%s: нет выбора" % id)
	if game.events.size() < 135:
		errors.append("событий меньше 135: %d" % game.events.size())
	for number in [1, 2, 3]:
		if int(per_chapter.get(number, 0)) < 42:
			errors.append("в главе %d мало событий: %d" % [number, per_chapter.get(number, 0)])
	if str(game.meta.get("opening_event", "")) == "":
		errors.append("нет opening_event")


func _check_chains(game: Node, errors: Array[String]) -> void:
	game.start_run(1)
	if str(game.pending.get("id", "")) != "knock_soft":
		errors.append("день 1 не открывается стуком, а %s" % game.pending.get("id", ""))
	var chains := [
		{"flags": ["let_neighbor"], "day": 8, "id": "neighbor_later"},
		{"flags": ["refused_neighbor"], "day": 8, "id": "neighbor_note"},
		{"flags": ["has_keys"], "day": 12, "id": "keys_flat"},
		{"flags": ["has_dog"], "day": 9, "id": "dog_warns"},
		{"flags": ["trader_fair"], "day": 12, "id": "trader_back"},
		{"flags": ["trader_robbed"], "day": 12, "id": "trader_revenge"},
		{"flags": ["basement_shut"], "day": 14, "id": "basement_smell"},
		{"flags": ["has_radio"], "day": 10, "id": "radio_name"},
		{"flags": ["knows_broadcast"], "day": 14, "id": "yard_cache"},
		{"flags": ["window_watcher"], "day": 10, "id": "window_fingers"},
		{"flags": ["has_kid"], "day": 10, "id": "kid_fever"},
		{"flags": ["kid_saved"], "day": 16, "id": "kid_night"},
		{"flags": ["mirror_knows"], "day": 18, "id": "mirror_day"},
		{"flags": ["cult_debt"], "day": 18, "id": "cult_due"},
		{"flags": ["believed_soldier"], "day": 16, "id": "evac_lie"},
		{"flags": ["warned_27"], "day": 27, "id": "day27"},
		{"flags": ["saved_cat_food"], "day": 12, "stats": {"food": 1}, "id": "black_day"},
	]
	for chain in chains:
		game.start_run(2)
		game.chapter = 1
		game.day = int(chain.day)
		for flag in chain.flags:
			game.flags[flag] = true
			game.flag_order.append(flag)
		if chain.has("stats"):
			for key in chain.stats.keys():
				game.stats[key] = int(chain.stats[key])
		var ids: Array = game.eligible_ids()
		if not ids.has(chain.id):
			errors.append("цепочка %s не доступна на дне %s" % [chain.id, chain.day])


func _play_many(game: Node, policy: String, count: int) -> Dictionary:
	var wins := 0
	var deaths := 0
	var days := 0
	var longest := 0
	var ammo_events := 0
	var causes := {}
	var reached := [0, 0, 0]
	var cleared := [0, 0, 0]
	var highlight_sum := [0, 0, 0]
	var max_repeat := 0
	var worst_name := ""
	var fallback := 0
	for seed in count:
		var result: Dictionary = _play(game, policy, 1000 + seed)
		var end_day := int(result.get("total", 0))
		days += end_day
		ammo_events += int(result.get("ammo", 0))
		longest = maxi(longest, end_day)
		max_repeat = maxi(max_repeat, int(result.get("max_repeat", 0)))
		if int(result.get("max_repeat", 0)) == max_repeat:
			worst_name = str(result.get("worst", worst_name))
		fallback = maxi(fallback, int(result.get("fallback", 0)))
		var got: Array = result.get("reached", [0, 0, 0])
		var done: Array = result.get("cleared", [0, 0, 0])
		var marks: Array = result.get("highlights", [0, 0, 0])
		for i in 3:
			reached[i] += int(got[i])
			cleared[i] += int(done[i])
			highlight_sum[i] += int(marks[i])
		if game.won:
			wins += 1
		else:
			deaths += 1
			var title := str(game.ending_title)
			causes[title] = int(causes.get(title, 0)) + 1
	return {
		"wins": wins,
		"deaths": deaths,
		"avg_total": float(days) / float(count),
		"longest": longest,
		"ammo_events": ammo_events,
		"reached": reached,
		"cleared": cleared,
		"highlights": highlight_sum,
		"max_repeat": max_repeat,
		"worst": worst_name,
		"fallback": fallback,
		"causes": causes,
	}


func _check_rates(result: Dictionary, count: int, errors: Array[String]) -> void:
	var cleared: Array = result.get("cleared", [0, 0, 0])
	var reached: Array = result.get("reached", [0, 0, 0])
	var marks: Array = result.get("highlights", [0, 0, 0])
	var rate1 := float(cleared[0]) / float(count)
	var rate2 := float(cleared[1]) / float(maxi(1, int(reached[1])))
	var rate3 := float(cleared[2]) / float(maxi(1, int(reached[2])))
	print("rates ch1 ", rate1, " ch2 ", rate2, " ch3 ", rate3)
	print("reached ", reached, " cleared ", cleared, " highlights ", marks)
	if rate1 < 0.55 or rate1 > 0.65:
		errors.append("глава 1 вне 55–65%%: %.2f" % rate1)
	if int(reached[1]) < 20:
		errors.append("до главы 2 дошло слишком мало: %d" % int(reached[1]))
	elif rate2 < 0.45 or rate2 > 0.55:
		errors.append("глава 2 вне 45–55%% от дошедших: %.2f" % rate2)
	if int(reached[2]) < 8:
		errors.append("до главы 3 дошло слишком мало: %d" % int(reached[2]))
	elif rate3 < 0.45 or rate3 > 0.55:
		errors.append("глава 3 вне 45–55%% от дошедших: %.2f" % rate3)
	if int(result.get("max_repeat", 0)) > 3:
		errors.append("уникальное событие повторилось %d раз (%s)" % [int(result.get("max_repeat", 0)), result.get("worst", "?")])
	if int(result.get("fallback", 0)) > 2:
		errors.append("пустой пул: тихий запасной день %d раз" % int(result.get("fallback", 0)))
	for i in 3:
		if int(cleared[i]) <= 0:
			continue
		var mean := float(marks[i]) / float(cleared[i])
		print("highlight_mean ch", i + 1, " ", mean)
		if mean < 1.5 or mean > 3.4:
			errors.append("изюминок в главе %d не 2–3: %.2f" % [i + 1, mean])


func _play(game: Node, policy: String, seed: int) -> Dictionary:
	game.start_run(seed)
	var guard := 0
	var ammo_seen := 0
	var counts := {}
	var reached := [1, 0, 0]
	var cleared := [0, 0, 0]
	var marks := [0, 0, 0]
	var pending_marks := 0
	while not game.run_over and guard < 120:
		var event_id := str(game.pending.get("id", ""))
		counts[event_id] = int(counts.get(event_id, 0)) + 1
		if bool(game.pending.get("highlight", false)):
			pending_marks += 1
		if _is_ammo_event(game.pending):
			ammo_seen += 1
		var which := _pick_choice(game, policy)
		var before := int(game.chapter)
		game.choose(which)
		if game.chapter_break:
			cleared[before - 1] += 1
			marks[before - 1] += pending_marks
			pending_marks = 0
			game.advance_chapter()
			var now := clampi(int(game.chapter) - 1, 0, 2)
			reached[now] = 1
		elif game.won:
			cleared[before - 1] += 1
			marks[before - 1] += pending_marks
			pending_marks = 0
		guard += 1
	var max_repeat := 0
	var worst := ""
	var fillers := {
		"scraps": true, "quiet": true, "dog_hungry": true,
		"roof_crumbs": true, "roof_quiet": true, "gutter_soup": true, "antenna_tin": true,
		"road_berries": true, "road_quiet": true, "kiosk_crumbs": true, "garden_weed": true,
		"jar_night": true, "_quiet_fallback": true,
	}
	for key in counts.keys():
		if fillers.has(str(key)):
			continue
		if int(counts[key]) > max_repeat:
			max_repeat = int(counts[key])
			worst = str(key)
	return {
		"day": game.day,
		"total": game.total_day(),
		"ammo": ammo_seen,
		"reached": reached,
		"cleared": cleared,
		"highlights": marks,
		"max_repeat": max_repeat,
		"worst": worst,
		"fallback": int(counts.get("_quiet_fallback", 0)),
	}


func _is_ammo_event(ev: Dictionary) -> bool:
	for which in ["a", "b"]:
		var branch: Variant = ev.get(which, {})
		if _touches_ammo(branch):
			return true
	return false


func _touches_ammo(branch: Variant) -> bool:
	if typeof(branch) != TYPE_DICTIONARY:
		return false
	var effects: Variant = branch.get("effects", {})
	var needs: Variant = branch.get("needs", {})
	if typeof(effects) == TYPE_DICTIONARY and effects.has("ammo"):
		return true
	if typeof(needs) == TYPE_DICTIONARY and needs.has("ammo"):
		return true
	if typeof(branch.get("blocked", null)) == TYPE_DICTIONARY and _touches_ammo(branch.blocked):
		return true
	var roll: Variant = branch.get("roll", [])
	if typeof(roll) == TYPE_ARRAY:
		for entry in roll:
			if _touches_ammo(entry):
				return true
	return false


func _pick_choice(game: Node, policy: String) -> String:
	if policy == "random":
		return "a" if game.rng.randi() % 2 == 0 else "b"
	var score_a := _score(game, "a", policy)
	var score_b := _score(game, "b", policy)
	if policy == "reckless":
		return "a" if score_a < score_b else "b"
	return "a" if score_a >= score_b else "b"


func _score(game: Node, which: String, policy: String) -> float:
	var raw: Dictionary = game.pending.get(which, {})
	var reckless := policy == "reckless"
	if _needs_blocked(game, raw):
		raw = raw.get("blocked", raw)
	if raw.has("roll"):
		var total := 0.0
		var weight := 0.0
		var deadly := false
		for entry in raw.roll:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var w := float(maxi(1, int(entry.get("w", 1))))
			weight += w
			if bool(entry.get("kill", false)):
				deadly = true
				total += (-1000.0 if not reckless else 1000.0) * w
			else:
				total += _effect_score(game, entry.get("effects", {})) * w
		var mean := total / maxf(1.0, weight)
		if deadly and not reckless:
			mean -= 80.0
		return mean
	if bool(raw.get("kill", false)):
		return 1000.0 if reckless else -1000.0
	return _effect_score(game, raw.get("effects", {}))


func _needs_blocked(game: Node, raw: Dictionary) -> bool:
	var needs: Dictionary = raw.get("needs", {})
	for key in needs.keys():
		if int(game.stats.get(str(key), 0)) < int(needs[key]):
			return raw.has("blocked")
	return false


func _effect_score(game: Node, effects: Variant) -> float:
	if typeof(effects) != TYPE_DICTIONARY:
		return 0.0
	var score := 0.0
	var food_delta := 0
	for key in effects.keys():
		var stat_id := str(key)
		var delta := int(effects[key])
		var current := int(game.stats.get(stat_id, 0))
		var weight := 1.0
		match stat_id:
			"food":
				food_delta = delta
				weight = 12.0 if current <= 2 else 2.0
			"health":
				weight = 14.0 if current <= 3 else 6.0
			"sanity":
				weight = 9.0 if current <= 2 else 2.2
			"ammo":
				weight = 0.4
		score += float(delta) * weight
		if delta < 0 and stat_id == "health" and current + delta <= 1:
			score -= 80.0
		if delta < 0 and stat_id == "sanity" and current + delta <= 0:
			score -= 250.0
		if delta < 0 and stat_id == "health" and current + delta <= 0:
			score -= 250.0
	var food_now := int(game.stats.get("food", 0)) + food_delta
	if food_now <= 0:
		score -= 90.0
	return score


func _scripted_death(game: Node, errors: Array[String]) -> void:
	game.start_run(3)
	game.day = 20
	game.flags["cult_debt"] = true
	game.pending = game.by_id["cult_due"]
	game.stats["health"] = 5
	game.stats["sanity"] = 5
	game.stats["food"] = 5
	var reveal: Dictionary = game.choose("b")
	if not bool(reveal.get("dead", false)) or game.won:
		errors.append("хор не убивает согласившегося")
	if game.ending_title != "Вступил в хор":
		errors.append("неверная карточка смерти: %s" % game.ending_title)

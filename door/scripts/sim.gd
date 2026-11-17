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
	var careful := _play_many(game, "careful", 40)
	var reckless := _play_many(game, "reckless", 20)
	var random_runs := _play_many(game, "random", 30)
	print("careful ", careful)
	print("reckless ", reckless)
	print("random ", random_runs)
	if int(careful.get("wins", 0)) < 1:
		errors.append("осторожная стратегия ни разу не дожила до победы")
	if int(reckless.get("deaths", 0)) < 1:
		errors.append("безрассудная стратегия ни разу не умерла")
	if int(random_runs.get("deaths", 0)) < 1:
		errors.append("случайная стратегия ни разу не умерла")
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
	var scenes := {
		"door": true, "open": true, "basement": true, "window": true, "stranger": true,
		"radio": true, "dog": true, "street": true, "mirror": true, "kid": true,
		"horde": true, "gun": true, "letter": true, "food": true, "cult": true,
		"soldier": true, "quiet": true,
	}
	for ev in game.events:
		var id := str(ev.get("id", ""))
		if not scenes.has(str(ev.get("scene", ""))):
			errors.append("%s: неизвестная сцена %s" % [id, ev.get("scene", "")])
		if typeof(ev.get("a")) != TYPE_DICTIONARY or typeof(ev.get("b")) != TYPE_DICTIONARY:
			errors.append("%s: нет выбора" % id)
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
	var causes := {}
	for seed in count:
		var end_day := _play(game, policy, 1000 + seed)
		days += end_day
		longest = maxi(longest, end_day)
		if game.won:
			wins += 1
		else:
			deaths += 1
			var title := str(game.ending_title)
			causes[title] = int(causes.get(title, 0)) + 1
	return {
		"wins": wins,
		"deaths": deaths,
		"avg_day": float(days) / float(count),
		"longest": longest,
		"causes": causes,
	}


func _play(game: Node, policy: String, seed: int) -> int:
	game.start_run(seed)
	var guard := 0
	while not game.run_over and guard < 40:
		var which := _pick_choice(game, policy)
		game.choose(which)
		guard += 1
	return game.day


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

extends RefCounted
## Короткий бой: три заклинания до обмена, враг ходит сам после каскада.

const WEAPONS := {
	"baguette": {"name": "Засохший батон", "dmg": [6, 8, 11], "stun": 0.0, "pierce": false, "ammo": false},
	"pan": {"name": "Сковорода «тёщина»", "dmg": [8, 10, 13], "stun": 0.2, "pierce": false, "ammo": false},
	"crowbar": {"name": "Лом из подвала", "dmg": [10, 13, 16], "stun": 0.0, "pierce": true, "ammo": false},
	"rifle": {"name": "Винтовка с чердака", "dmg": [14, 18, 22], "stun": 0.0, "pierce": false, "ammo": true},
}
const ORDER: Array[String] = ["baguette", "pan", "crowbar", "rifle"]

var rng: RandomNumberGenerator
var game: Node
var board: RefCounted
var hp := 40
var shield := 0
var energy := 0
var heal_used := 0
var lure := 0
var enemy: Dictionary = {}
var minion_hp := 0
var turn := "player"
var swapped := false
var over := false
var victory := false
var enemy_turns := 0
var hero_stun := 0
var enemy_stun := 0
var jammed: Dictionary = {}
var stole := false
var whistled := false
var first_hit := true
var log_line := ""
var weapon := "baguette"


func start(owner: Node, spec: Dictionary) -> void:
	game = owner
	rng = owner.rng
	board = preload("res://scripts/match3.gd").new()
	board.build(rng)
	weapon = str(owner.weapon)
	hp = int(owner.stats.get("health", 40))
	shield = 4 if owner.artifacts.has("plastic_bag") else 0
	energy = 2 if owner.artifacts.has("coffee_3in1") else 0
	if owner.artifacts.has("sticking_plaster"):
		_heal(2, false)
	enemy = _make_enemy(spec)
	log_line = "%s смотрит на вас. %s" % [enemy["name"], enemy["intent"]]


func hero_max() -> int:
	return game.stat_max("health")


func cast(spell_id: String) -> bool:
	if over or turn != "player" or swapped:
		return false
	if int(jammed.get(spell_id, 0)) > 0:
		log_line = "Заклинание заклинило."
		return false
	var cost := _spell_cost(spell_id)
	if energy < cost:
		log_line = "Мало энергии."
		return false
	energy -= cost
	match spell_id:
		"shot":
			_hurt_enemy(8)
			log_line = "Выстрел. Враг получает 8."
		"grenade":
			var dmg := 16 if game.artifacts.has("training_grenade") else 12
			_hurt_enemy(dmg)
			_scramble(5 if game.artifacts.has("training_grenade") else 3)
			log_line = "Граната. Клетки разлетелись."
		"kit":
			_heal(8, true)
			hero_stun = 0
			board.clear_curses()
			log_line = "Аптечка. Дышать легче."
		_:
			energy += cost
			return false
	if enemy["hp"] <= 0 and minion_hp <= 0:
		_win()
	return true


func player_swap(r1: int, c1: int, r2: int, c2: int) -> bool:
	if over or turn != "player" or swapped:
		return false
	if hero_stun > 0:
		hero_stun -= 1
		log_line = "Вы оглушены и пропускаете обмен."
		_enemy_phase()
		return true
	if not board.try_swap(r1, c1, r2, c2):
		log_line = "Так камни не встают."
		return false
	swapped = true
	var runs: Array = board.resolve(rng)
	for run in runs:
		_award(run)
		if over:
			return true
	if enemy["hp"] <= 0 and minion_hp <= 0:
		_win()
		return true
	_enemy_phase()
	return true


func autoplay() -> bool:
	var guard := 0
	while not over and guard < 48:
		guard += 1
		if turn != "player":
			break
		var atk := int(enemy.get("atk", 4))
		if hp <= atk + 2 and energy >= _spell_cost("kit"):
			cast("kit")
		elif int(enemy["hp"]) + minion_hp >= 18 and energy >= _spell_cost("grenade") and hp > atk * 2:
			cast("grenade")
		elif energy >= _spell_cost("shot") and int(enemy["hp"]) + minion_hp <= 16 and hp > atk + 2:
			cast("shot")
		if over:
			return victory
		var prefer := "baguette"
		if hp <= atk + 4:
			prefer = "bandage"
		elif energy < 2 and int(enemy["hp"]) > 20 and rng.randi() % 4 == 0:
			prefer = "brains"
		var swap: Array = board.best_swap(prefer)
		if swap.is_empty():
			swap = board.best_swap("baguette")
		if swap.is_empty():
			board.build(rng)
			swap = board.best_swap("baguette")
		if swap.is_empty():
			break
		player_swap(swap[0], swap[1], swap[2], swap[3])
	return victory


func _enemy_phase() -> void:
	if over:
		return
	board.clear_curses()
	turn = "enemy"
	enemy_turns += 1
	_tick_jam()
	if enemy_stun > 0:
		enemy_stun -= 1
		log_line = "%s пропускает ход." % enemy["name"]
		_begin_player_turn()
		return
	_trick_before()
	if over:
		return
	var hits := 2 if bool(enemy.get("double", false)) else 1
	var dmg := int(enemy["atk"])
	if int(enemy.get("club_every", 0)) > 0 and enemy_turns % int(enemy["club_every"]) == 0:
		dmg = int(enemy["club"])
		log_line = "%s: дубинка." % enemy["name"]
	else:
		log_line = "%s бьёт." % enemy["name"]
	for _i in hits:
		_hurt_hero(dmg)
		if over:
			return
	_begin_player_turn()


func _begin_player_turn() -> void:
	if over:
		return
	turn = "player"
	swapped = false
	if game.artifacts.has("sticking_plaster"):
		_heal(2, true)
	enemy["intent"] = _intent_text()


func _trick_before() -> void:
	var kind := str(enemy.get("trick", ""))
	if kind == "swarm" and enemy_turns == 3 and minion_hp <= 0 and not bool(enemy.get("spawned", false)):
		minion_hp = 8
		enemy["spawned"] = true
		log_line = "Из щели лезет ещё один таракан."
	elif kind == "steal" and not stole:
		var taken := str(board.steal(rng, ["baguette", "bandage"]))
		stole = true
		log_line = "Крыса утаскивает %s." % taken
	elif kind == "poop":
		board.curse_cells(rng, 2)
		log_line = "Голубь метит две клетки. Их не сдвинуть."
	elif kind == "jam" and enemy_turns % 3 == 0:
		var spells := ["shot", "grenade", "kit"]
		var spell: String = spells[rng.randi_range(0, 2)]
		jammed[spell] = int(enemy.get("jam_turns", 1))
		log_line = "Пульт глушит заклинание."
	elif kind == "lunge" and enemy_turns % 3 == 0:
		enemy["double"] = true
	else:
		enemy["double"] = false
	if kind == "shield" and enemy_turns % 2 == 0:
		enemy["shield"] = int(enemy.get("shield", 0)) + int(enemy.get("shield_gain", 8))
	if kind == "shield" and enemy_turns == 4 and not whistled:
		whistled = true
		if str(enemy.get("whistle", "cockroach")) == "rat":
			minion_hp = 12
			log_line = "Свисток. Из-за угла крыса."
		else:
			minion_hp = 8
			log_line = "Свисток. Таракан по разнарядке."


func _award(run: Dictionary) -> void:
	var type := str(run.get("type", ""))
	var n := int(run.get("n", 0))
	var combo := int(run.get("combo", 1))
	if type == "_shuffle" or n <= 0:
		log_line = "Поле перемешалось."
		return
	var tier := 0 if n <= 3 else (1 if n == 4 else 2)
	var bonus := combo - 1 if combo > 1 else 0
	match type:
		"baguette":
			var dmg := _weapon_damage(tier) + lure + bonus
			if game.artifacts.has("raisa_pepper"):
				dmg += 2
			if first_hit and game.artifacts.has("zhek_notebook"):
				dmg = maxi(1, dmg / 2)
			first_hit = false
			lure = 0
			_hurt_enemy(dmg)
			log_line = "Удар: %d." % dmg
		"brains":
			energy = mini(10, energy + 1 + bonus)
			lure += 2
			if game.artifacts.has("radio_antenna"):
				lure += 1
				if n >= 4:
					energy = mini(10, energy + 1)
			log_line = "Мозги. Следующий удар злее."
		"bandage":
			var heal: int = int([0, 0, 0, 4, 6, 9][mini(5, n)]) + bonus
			if game.artifacts.has("electrical_tape"):
				heal += 2
			_heal(heal, true)
			if n >= 4:
				board.clear_curses()
			log_line = "Бинт."
		"energy_drink":
			var gain := 6 if n >= 5 else n
			energy = mini(10, energy + gain + bonus)
			log_line = "Энергетик +%d." % gain
		"pot_lid":
			var block := 8 if n >= 5 else (5 if n >= 4 else 3)
			shield += block + bonus
			log_line = "Крышка. Щит +%d." % block
	if enemy["hp"] <= 0 and minion_hp <= 0:
		_win()


func _weapon_damage(tier: int) -> int:
	var spec: Dictionary = WEAPONS[weapon]
	var using := weapon
	if bool(spec["ammo"]):
		if int(game.stats.get("ammo", 0)) <= 0:
			using = "crowbar"
		else:
			game.stats["ammo"] = int(game.stats["ammo"]) - 1
	var row: Array = WEAPONS[using]["dmg"]
	var dmg := int(row[tier])
	if float(WEAPONS[using]["stun"]) > 0.0 and rng.randf() < float(WEAPONS[using]["stun"]):
		enemy_stun += 1
	if not bool(WEAPONS[using]["pierce"]):
		pass
	else:
		enemy["pierce_next"] = true
	return dmg


func _hurt_enemy(amount: int) -> void:
	var left := amount
	var pierce := bool(enemy.get("pierce_next", false))
	enemy["pierce_next"] = false
	if not pierce and int(enemy.get("shield", 0)) > 0:
		var absorbed := mini(int(enemy["shield"]), left)
		enemy["shield"] = int(enemy["shield"]) - absorbed
		left -= absorbed
	if int(enemy["hp"]) > 0 and left > 0:
		enemy["hp"] = int(enemy["hp"]) - left
		if int(enemy["hp"]) < 0:
			left = -int(enemy["hp"])
			enemy["hp"] = 0
		else:
			left = 0
	if left > 0 and minion_hp > 0:
		minion_hp = maxi(0, minion_hp - left)
	if int(enemy["hp"]) <= 0 and minion_hp <= 0:
		_win()


func _hurt_hero(amount: int) -> void:
	var left := amount
	if shield > 0:
		var absorbed := mini(shield, left)
		shield -= absorbed
		left -= absorbed
	hp = maxi(0, hp - left)
	game.stats["health"] = hp
	if hp <= 0:
		over = true
		victory = false
		log_line = "Вас добили."


func _heal(amount: int, capped: bool) -> void:
	var grant := amount
	if capped:
		var room := maxi(0, 15 - heal_used)
		var healed := mini(room, grant)
		heal_used += healed
		shield += grant - healed
		grant = healed
	hp = mini(hero_max(), hp + grant)
	game.stats["health"] = hp


func _spell_cost(spell_id: String) -> int:
	var costs := {"shot": 2, "grenade": 4, "kit": 3}
	var cost := int(costs.get(spell_id, 99))
	if game.artifacts.has("postman_whistle"):
		cost = maxi(1, cost - 1)
	return cost


func _scramble(count: int) -> void:
	for _i in count:
		var r := rng.randi_range(0, 4)
		var c := rng.randi_range(0, 5)
		board.grid[r][c] = board._random_type(rng)


func _tick_jam() -> void:
	for key in jammed.keys():
		jammed[key] = int(jammed[key]) - 1
		if int(jammed[key]) <= 0:
			jammed.erase(key)


func _win() -> void:
	over = true
	victory = true
	game.stats["health"] = hp
	log_line = "Враг падает."
	if str(enemy.get("id", "")) == "uber_cop" and not game.flat_medal:
		game.flat_medal = true
		game.bonus_max_hp += 5
		game._save_meta()


func _intent_text() -> String:
	if enemy_stun > 0:
		return "пропустит ход"
	if str(enemy.get("trick", "")) == "shield" and (enemy_turns + 1) % 2 == 0:
		return "поднимет щит"
	if int(enemy.get("club_every", 0)) > 0 and (enemy_turns + 1) % int(enemy["club_every"]) == 0:
		return "дубинка %d" % int(enemy["club"])
	return "удар %d" % int(enemy["atk"])


func _make_enemy(spec: Dictionary) -> Dictionary:
	var species := str(spec.get("enemy", "rat"))
	var subtype := str(spec.get("subtype", ""))
	if subtype == "":
		subtype = ["a", "b", "v"][rng.randi_range(0, 2)]
	var table := _catalog()
	var base: Dictionary = table[species][subtype]
	var foe := base.duplicate()
	foe["id"] = species
	foe["subtype"] = subtype
	foe["hp"] = int(foe["max_hp"])
	foe["shield"] = 0
	enemy = foe
	enemy["intent"] = _intent_text()
	return enemy


func _catalog() -> Dictionary:
	return {
		"cockroach": {
			"a": {"name": "Таракан на дыбах", "max_hp": 24, "atk": 4, "trick": "swarm"},
			"b": {"name": "Таракан в прыжке", "max_hp": 18, "atk": 5, "trick": "swarm"},
			"v": {"name": "Таракан под тапком", "max_hp": 12, "atk": 3, "trick": "swarm"},
		},
		"rat": {
			"a": {"name": "Тощая крыса", "max_hp": 20, "atk": 6, "trick": "steal"},
			"b": {"name": "Сытая крыса", "max_hp": 29, "atk": 4, "trick": "steal"},
			"v": {"name": "Крыса с банкой", "max_hp": 22, "atk": 5, "trick": "steal"},
		},
		"pigeon": {
			"a": {"name": "Голубь", "max_hp": 16, "atk": 3, "trick": "poop"},
			"b": {"name": "Голубь", "max_hp": 18, "atk": 3, "trick": "poop"},
			"v": {"name": "Голубь", "max_hp": 14, "atk": 4, "trick": "poop"},
		},
		"small_zombie": {
			"a": {"name": "Зомби в худи", "max_hp": 40, "atk": 4, "trick": "jam", "jam_turns": 1},
			"b": {"name": "Зомби в халате", "max_hp": 52, "atk": 4, "trick": "jam", "jam_turns": 1},
			"v": {"name": "Зомби с пультом", "max_hp": 36, "atk": 5, "trick": "jam", "jam_turns": 2},
		},
		"zombie_dog": {
			"a": {"name": "Жалкий зомби-пёс", "max_hp": 36, "atk": 4, "trick": "lunge"},
			"b": {"name": "Злой зомби-пёс", "max_hp": 44, "atk": 5, "trick": "lunge"},
			"v": {"name": "Пёс с банкой на хвосте", "max_hp": 48, "atk": 5, "trick": "lunge"},
		},
		"uber_cop": {
			"a": {"name": "Участковый, щиток поднят", "max_hp": 56, "atk": 4, "trick": "shield", "shield_gain": 3, "club": 8, "club_every": 3, "whistle": "cockroach"},
			"b": {"name": "Участковый, щиток опущен", "max_hp": 72, "atk": 5, "trick": "shield", "shield_gain": 4, "club": 10, "club_every": 3, "whistle": "cockroach"},
			"v": {"name": "Толстый участковый", "max_hp": 64, "atk": 4, "trick": "shield", "shield_gain": 3, "club": 9, "club_every": 3, "whistle": "rat"},
		},
	}
